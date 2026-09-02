class AppConstants {
  static const appName = 'Work Pulse';
  static const introSeenKey = 'intro_seen';
  static const locationPingInterval = Duration(seconds: 30);
  static const attendanceLookback = Duration(days: 62);
  static const leavePastDays = 10;
  static const leaveFutureDays = 60;
  static const leaveMaxDays = 30;
  static const checkoutPhotoCount = 5;

  static const jobTypes = [
    'Installation',
    'Maintenance',
    'Inspection',
    'Survey',
    'Delivery',
    'Support',
    'Other',
  ];

  static const jobCategories = [
    'Scheduled',
    'Emergency',
    'Follow-up',
    'Onsite',
    'Remote',
    'Other',
  ];
}
