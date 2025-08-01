import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ride_group.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/location_picker.dart';
import '../../core/errors/app_error.dart';
import '../../core/utils/validators.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();
  final _totalFareController = TextEditingController();
  
  LatLng? _pickupCoordinates;
  LatLng? _destinationCoordinates;
  DateTime? _scheduledTime;
  int _totalSeats = 4;
  bool _femaleOnly = false;
  double? _estimatedDistance;
  double? _suggestedFare;

  double get _pricePerPerson {
    final totalFare = double.tryParse(_totalFareController.text) ?? 0.0;
    return _totalSeats > 0 ? totalFare / _totalSeats : 0.0;
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    _totalFareController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getErrorMessage(error)),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getErrorMessage(AppError error) {
    switch (error.type) {
      case ErrorType.network:
        return 'Network error: ${error.message}';
      case ErrorType.validation:
        return error.message;
      default:
        return 'Error: ${error.message}';
    }
  }

  Future<void> _calculateDistanceAndFare() async {
    if (_pickupCoordinates != null && _destinationCoordinates != null) {
      final rideProvider = context.read<RideProvider>();
      
      try {
        _estimatedDistance = await rideProvider.calculateDistance(
          _pickupCoordinates!,
          _destinationCoordinates!,
        );
        
        _suggestedFare = await rideProvider.calculateFare(
          _pickupCoordinates!,
          _destinationCoordinates!,
          _totalSeats,
        );
        
        if (mounted) {
          setState(() {});
          
          // Auto-fill fare if not already set
          if (_totalFareController.text.isEmpty && _suggestedFare != null) {
            _totalFareController.text = _suggestedFare!.toStringAsFixed(2);
          }
        }
      } catch (e) {
        // Handle error silently or show a message
        debugPrint('Failed to calculate distance/fare: $e');
      }
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _scheduledTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createRide() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_pickupCoordinates == null || _destinationCoordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup and destination locations')),
      );
      return;
    }
    
    if (_scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();
    
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create a ride')),
      );
      return;
    }

    final user = authProvider.user!;
    final totalFare = double.parse(_totalFareController.text);
    
    final ride = RideGroup(
      id: '', // Will be set by service
      leaderId: user.uid,
      pickupLocation: _pickupController.text.trim(),
      pickupCoordinates: _pickupCoordinates!,
      destination: _destinationController.text.trim(),
      destinationCoordinates: _destinationCoordinates!,
      scheduledTime: _scheduledTime!,
      totalSeats: _totalSeats,
      availableSeats: _totalSeats - 1, // Leader takes one seat
      totalFare: totalFare,
      pricePerPerson: totalFare / _totalSeats, // Price includes leader
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      femaleOnly: _femaleOnly,
      createdAt: DateTime.now(),
    );

    await rideProvider.createRide(ride);

    if (rideProvider.error == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // Return true to indicate success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Ride'),
        actions: [
          Consumer<RideProvider>(
            builder: (context, rideProvider, child) {
              return TextButton(
                onPressed: rideProvider.isCreating ? null : _createRide,
                child: rideProvider.isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              );
            },
          ),
        ],
      ),
      body: Consumer<RideProvider>(
        builder: (context, rideProvider, child) {
          if (rideProvider.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showErrorSnackBar(rideProvider.error!);
              rideProvider.clearError();
            });
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
            // Pickup Location
            TextFormField(
              controller: _pickupController,
              decoration: const InputDecoration(
                labelText: 'Pickup Location',
                prefixIcon: Icon(Icons.my_location),
              ),
              validator: (value) => Validators.validateLocation(value),
              onTap: () async {
                final result = await Navigator.of(context).push<Map<String, dynamic>>(
                  MaterialPageRoute(
                    builder: (context) => const LocationPickerScreen(
                      title: 'Select Pickup Location',
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _pickupController.text = result['address'];
                    _pickupCoordinates = result['coordinates'];
                  });
                  _calculateDistanceAndFare();
                }
              },
              readOnly: true,
            ),
            const SizedBox(height: 16),

            // Destination
            TextFormField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (value) => Validators.validateLocation(value),
              onTap: () async {
                final result = await Navigator.of(context).push<Map<String, dynamic>>(
                  MaterialPageRoute(
                    builder: (context) => const LocationPickerScreen(
                      title: 'Select Destination',
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _destinationController.text = result['address'];
                    _destinationCoordinates = result['coordinates'];
                  });
                  _calculateDistanceAndFare();
                }
              },
              readOnly: true,
            ),
            const SizedBox(height: 16),

            // Date and Time
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(_scheduledTime == null
                  ? 'Select Date & Time'
                  : '${_scheduledTime!.day}/${_scheduledTime!.month}/${_scheduledTime!.year} at ${_scheduledTime!.hour}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _selectDateTime,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 16),

            // Total Seats
            Row(
              children: [
                const Icon(Icons.airline_seat_recline_normal),
                const SizedBox(width: 16),
                const Text('Total Seats:'),
                const Spacer(),
                IconButton(
                  onPressed: _totalSeats > 2 ? () => setState(() => _totalSeats--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$_totalSeats'),
                IconButton(
                  onPressed: _totalSeats < 8 ? () => setState(() => _totalSeats++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total Fare
            TextFormField(
              controller: _totalFareController,
              decoration: InputDecoration(
                labelText: 'Total Fare (\$)',
                prefixIcon: const Icon(Icons.attach_money),
                helperText: 'Price per person: \$${_pricePerPerson.toStringAsFixed(2)}',
              ),
              keyboardType: TextInputType.number,
              validator: Validators.validateFare,
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                prefixIcon: Icon(Icons.note),
                hintText: 'Any additional information...',
              ),
              maxLines: 3,
              validator: Validators.validateNotes,
            ),
            const SizedBox(height: 16),

            // Female Only Toggle
            SwitchListTile(
              title: const Text('Female Only'),
              subtitle: const Text('Restrict this ride to female passengers only'),
              value: _femaleOnly,
              onChanged: (value) => setState(() => _femaleOnly = value),
              secondary: const Icon(Icons.woman),
            ),
            const SizedBox(height: 16),

            // Distance and Fare Info
            if (_estimatedDistance != null || _suggestedFare != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_estimatedDistance != null)
                        Row(
                          children: [
                            const Icon(Icons.straighten, size: 16),
                            const SizedBox(width: 8),
                            Text('Distance: ${_estimatedDistance!.toStringAsFixed(1)} km'),
                          ],
                        ),
                      if (_suggestedFare != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.attach_money, size: 16),
                            const SizedBox(width: 8),
                            Text('Suggested fare: \$${_suggestedFare!.toStringAsFixed(2)}'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),

            // Create Button
            Consumer<RideProvider>(
              builder: (context, rideProvider, child) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: rideProvider.isCreating ? null : _createRide,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: rideProvider.isCreating
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Creating Ride...'),
                            ],
                          )
                        : const Text('Create Ride'),
                  ),
                );
              },
            ),
          ],
        ),
      );
        },
      ),
    );
  }
}