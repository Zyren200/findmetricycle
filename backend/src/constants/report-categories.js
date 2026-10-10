// What a "Report a Problem" can be about. Drivers and passengers pick from
// their own lists; every report lands in the admin's Complaints inbox,
// which shows the category with its underscores as spaces.

const DRIVER_REPORT_CATEGORIES = [
  "no_show",
  "incorrect_pickup",
  "fare_dispute",
  "safety_concern",
  "passenger_behavior",
  "other",
];

const PASSENGER_REPORT_CATEGORIES = [
  "booking_issue",
  "driver_issue",
  "fare_dispute",
  "safety_concern",
  "app_issue",
  "account_issue",
  "other",
];

const REPORT_CATEGORIES = [...new Set([...DRIVER_REPORT_CATEGORIES, ...PASSENGER_REPORT_CATEGORIES])];

module.exports = {
  DRIVER_REPORT_CATEGORIES,
  PASSENGER_REPORT_CATEGORIES,
  REPORT_CATEGORIES,
};
