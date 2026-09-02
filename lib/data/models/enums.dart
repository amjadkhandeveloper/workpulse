enum UserRole { admin, user }

enum StandbyStatus { out, in_ }

enum JobStatus {
  pending,
  accepted,
  declined,
  checkedIn,
  pendingReview,
  completed,
  cancelled,
}

enum LeaveStatus { pending, approved, rejected }

enum LeaveDayType { full, firstHalf, secondHalf }

enum AttendanceType { standbyIn, standbyOut }

enum ProofKind { photo, signature }

extension UserRoleX on UserRole {
  String get db => this == UserRole.admin ? 'admin' : 'user';
  static UserRole fromDb(String? value) =>
      value == 'admin' ? UserRole.admin : UserRole.user;
}

extension StandbyStatusX on StandbyStatus {
  String get db => this == StandbyStatus.in_ ? 'in' : 'out';
  static StandbyStatus fromDb(String? value) =>
      value == 'in' ? StandbyStatus.in_ : StandbyStatus.out;
}

extension JobStatusX on JobStatus {
  String get db => switch (this) {
        JobStatus.pending => 'pending',
        JobStatus.accepted => 'accepted',
        JobStatus.declined => 'declined',
        JobStatus.checkedIn => 'checked_in',
        JobStatus.pendingReview => 'pending_review',
        JobStatus.completed => 'completed',
        JobStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        JobStatus.pending => 'Pending',
        JobStatus.accepted => 'Enroute',
        JobStatus.declined => 'Declined',
        JobStatus.checkedIn => 'Checked In',
        JobStatus.pendingReview => 'Pending Review',
        JobStatus.completed => 'Completed',
        JobStatus.cancelled => 'Cancelled',
      };

  bool get isActive =>
      this == JobStatus.accepted || this == JobStatus.checkedIn;

  static JobStatus fromDb(String? value) => switch (value) {
        'accepted' => JobStatus.accepted,
        'declined' => JobStatus.declined,
        'checked_in' => JobStatus.checkedIn,
        'pending_review' => JobStatus.pendingReview,
        'completed' => JobStatus.completed,
        'cancelled' => JobStatus.cancelled,
        _ => JobStatus.pending,
      };
}

extension LeaveStatusX on LeaveStatus {
  String get db => name;
  static LeaveStatus fromDb(String? value) => switch (value) {
        'approved' => LeaveStatus.approved,
        'rejected' => LeaveStatus.rejected,
        _ => LeaveStatus.pending,
      };
}

extension LeaveDayTypeX on LeaveDayType {
  String get db => switch (this) {
        LeaveDayType.full => 'full',
        LeaveDayType.firstHalf => 'first_half',
        LeaveDayType.secondHalf => 'second_half',
      };

  String get label => switch (this) {
        LeaveDayType.full => 'Full day',
        LeaveDayType.firstHalf => 'First half',
        LeaveDayType.secondHalf => 'Second half',
      };

  static LeaveDayType fromDb(String? value) => switch (value) {
        'first_half' => LeaveDayType.firstHalf,
        'second_half' => LeaveDayType.secondHalf,
        _ => LeaveDayType.full,
      };
}

extension AttendanceTypeX on AttendanceType {
  String get db => this == AttendanceType.standbyIn ? 'standby_in' : 'standby_out';
  String get label => this == AttendanceType.standbyIn ? 'Standby In' : 'Standby Out';
  static AttendanceType fromDb(String? value) =>
      value == 'standby_out' ? AttendanceType.standbyOut : AttendanceType.standbyIn;
}
