# Requirements Document

## Introduction

RideLink is a collaborative cab-sharing mobile application built with Flutter that connects users traveling along similar routes. The app enables cost-effective transportation by allowing users to create or join ride-sharing groups, with a group leader managing the ride and coordinating with members. The platform focuses on safety, community building, and seamless user experience through Google authentication, real-time tracking, and integrated payments.

## Requirements

### Requirement 1

**User Story:** As a new user, I want to sign up and authenticate using my Google account, so that I can quickly access the platform with verified credentials.

#### Acceptance Criteria

1. WHEN a user opens the app for the first time THEN the system SHALL display a Google Sign-In option
2. WHEN a user completes Google authentication THEN the system SHALL automatically fetch their name and profile picture
3. WHEN authentication is successful THEN the system SHALL create a user profile with Google-provided information
4. IF authentication fails THEN the system SHALL display an appropriate error message and retry option

### Requirement 2

**User Story:** As a registered user, I want to complete and manage my profile, so that other users can view my information and build trust.

#### Acceptance Criteria

1. WHEN a user first logs in THEN the system SHALL prompt them to complete their profile with bio and phone number
2. WHEN a user updates their profile THEN the system SHALL save changes and display confirmation
3. WHEN viewing a user profile THEN the system SHALL display name, profile picture, bio, and average rating
4. WHEN a user has completed rides THEN the system SHALL calculate and display their average rating from other users

### Requirement 3

**User Story:** As a group leader, I want to create a new ride group with detailed journey information, so that other users can find and join my ride.

#### Acceptance Criteria

1. WHEN a user creates a ride THEN the system SHALL require pickup location via Google Maps integration
2. WHEN a user creates a ride THEN the system SHALL require destination via Google Maps integration
3. WHEN a user creates a ride THEN the system SHALL require date, time, available seats, and estimated total fare
4. WHEN fare details are entered THEN the system SHALL automatically calculate price per person
5. [REMOVED] Female-only option requirement removed
6. WHEN ride creation is complete THEN the system SHALL make the ride visible to other users

### Requirement 4

**User Story:** As a potential passenger, I want to search and browse available ride groups, so that I can find rides that match my travel needs.

#### Acceptance Criteria

1. WHEN a user accesses the main screen THEN the system SHALL display available ride groups in list or map view
2. WHEN a user searches by destination THEN the system SHALL filter rides based on location proximity
3. WHEN a user applies filters THEN the system SHALL show rides matching date, time, and destination criteria
4. WHEN a user views ride details THEN the system SHALL display leader profile, route, current members, and pricing

### Requirement 5

**User Story:** As a potential passenger, I want to request to join a ride group, so that I can participate in cost-effective shared transportation.

#### Acceptance Criteria

1. WHEN a user finds a suitable ride THEN the system SHALL provide a "Request to Join" option
2. WHEN a join request is sent THEN the system SHALL notify the group leader via push notification
3. WHEN a leader receives a request THEN the system SHALL display requester's profile and rating
4. WHEN a leader approves a request THEN the system SHALL add the member to the group and notify them

### Requirement 6

**User Story:** As a group leader, I want to manage my ride group members, so that I can maintain control over who participates in my ride.

#### Acceptance Criteria

1. WHEN a join request is received THEN the system SHALL allow the leader to accept or decline
2. WHEN a member is accepted THEN the system SHALL add them to the group chat and member list
3. WHEN necessary THEN the system SHALL allow the leader to remove members from the group
4. WHEN group changes occur THEN the system SHALL notify all affected members

### Requirement 7

**User Story:** As a ride group member, I want to communicate with other members through in-app chat, so that I can coordinate pickup details and stay informed.

#### Acceptance Criteria

1. WHEN a user joins a group THEN the system SHALL provide access to the group chat room
2. WHEN a message is sent THEN the system SHALL deliver it to all group members in real-time
3. WHEN a message is received THEN the system SHALL send push notifications to offline members
4. WHEN viewing chat THEN the system SHALL display sender names and timestamps

### Requirement 8

**User Story:** As a ride group member, I want to track the cab's real-time location during the journey, so that I can monitor progress and plan accordingly.

#### Acceptance Criteria

1. WHEN a group leader starts the ride THEN the system SHALL activate real-time location tracking
2. WHEN tracking is active THEN the system SHALL display the cab's current location to all members
3. WHEN the destination is reached THEN the system SHALL stop location tracking
4. IF location services are unavailable THEN the system SHALL notify users and provide alternative coordination methods

### Requirement 9

**User Story:** As a ride participant, I want to make secure payments through the app, so that I can pay my share conveniently and safely.

#### Acceptance Criteria

1. WHEN a user is accepted into a group THEN the system SHALL prompt for payment pre-authorization
2. WHEN a ride starts THEN the system SHALL capture the pre-authorized payment amount
3. WHEN a ride is completed THEN the system SHALL transfer collected payments to the group leader's account
4. IF payment fails THEN the system SHALL notify the user and provide retry options

### Requirement 10

**User Story:** As a ride participant, I want to rate and review other members after completing a ride, so that I can contribute to the community trust system.

#### Acceptance Criteria

1. WHEN a ride is marked complete THEN the system SHALL prompt all members to rate each other
2. WHEN submitting ratings THEN the system SHALL accept ratings on a 1-5 star scale
3. WHEN ratings are submitted THEN the system SHALL update each user's average rating
4. WHEN viewing profiles THEN the system SHALL display current average ratings to build trust

### Requirement 11

**User Story:** As a user, I want to view my ride history and manage upcoming rides, so that I can track my transportation activities.

#### Acceptance Criteria

1. WHEN accessing "My Rides" THEN the system SHALL display tabs for "Upcoming" and "Completed" rides
2. WHEN viewing upcoming rides THEN the system SHALL show ride details and group information
3. WHEN viewing completed rides THEN the system SHALL display ride history with ratings received
4. WHEN managing rides THEN the system SHALL allow cancellation of upcoming rides with appropriate notice

### Requirement 12 [REMOVED]

**Note:** Female-only ride option requirement has been removed from the system.