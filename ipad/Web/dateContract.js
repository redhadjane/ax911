(function initDateContract(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.HopDateContract = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function createDateContract() {
  "use strict";

  const RESTAURANT_TIME_ZONE = "America/New_York";
  const SCHEDULE_DAY_NAMES = ["Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

  function parseDateOnly(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value || ""))) throw new TypeError("Expected a date in YYYY-MM-DD format.");
    const [year, month, day] = String(value).split("-").map(Number);
    const date = new Date(Date.UTC(year, month - 1, day));
    if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
      throw new RangeError(`Invalid calendar date: ${value}`);
    }
    return date;
  }

  function formatDateOnly(date) {
    return new Date(date).toISOString().slice(0, 10);
  }

  function addDays(value, amount) {
    const date = parseDateOnly(value);
    date.setUTCDate(date.getUTCDate() + Number(amount));
    return formatDateOnly(date);
  }

  function dayOfWeek(value) {
    return parseDateOnly(value).getUTCDay();
  }

  function startOfTuesdayWeek(value) {
    const weekday = dayOfWeek(value);
    const daysSinceTuesday = (weekday - 2 + 7) % 7;
    return addDays(value, -daysSinceTuesday);
  }

  function endOfScheduleWeek(value) {
    return addDays(startOfTuesdayWeek(value), 5);
  }

  function scheduleDates(value) {
    const start = startOfTuesdayWeek(value);
    return SCHEDULE_DAY_NAMES.map((name, index) => ({ name, date: addDays(start, index) }));
  }

  function isScheduleDate(value) {
    const weekday = dayOfWeek(value);
    return weekday !== 1;
  }

  function dateInTimeZone(value, timeZone = RESTAURANT_TIME_ZONE) {
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) throw new RangeError(`Invalid instant: ${value}`);
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(date);
    const byType = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    return `${byType.year}-${byType.month}-${byType.day}`;
  }

  function today(now = new Date()) {
    return dateInTimeZone(now, RESTAURANT_TIME_ZONE);
  }

  function assertTuesdayWeekStart(value) {
    if (dayOfWeek(value) !== 2) throw new RangeError(`Schedule week must start on Tuesday: ${value}`);
    return value;
  }

  return {
    RESTAURANT_TIME_ZONE,
    SCHEDULE_DAY_NAMES,
    parseDateOnly,
    formatDateOnly,
    addDays,
    dayOfWeek,
    startOfTuesdayWeek,
    endOfScheduleWeek,
    scheduleDates,
    isScheduleDate,
    dateInTimeZone,
    today,
    assertTuesdayWeekStart,
  };
});
