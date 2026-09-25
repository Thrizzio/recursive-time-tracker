import { integer, pgTable, serial, timestamp, varchar, text, boolean } from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  googleId: varchar("google_id", { length: 255 }).notNull().unique(),
  email: varchar("email", { length: 255 }).notNull(),
  name: varchar("name", { length: 255 }).notNull(),
  avatarUrl: text("avatar_url"),
  googleRefreshToken: text("google_refresh_token"),
  googleAccessToken: text("google_access_token"),
  googleTokenExpiresAt: timestamp("google_token_expires_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  trackingStartedAt: timestamp("tracking_started_at", {
    withTimezone: true,
  }),
  selectedTaskListId: varchar("selected_task_list_id", { length: 255 }),
});

export const sessions = pgTable("sessions", {
  id: text("id").primaryKey(),
  userId: integer("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
});

export const activities = pgTable("activities", {
  id: serial("id").primaryKey(),
  userId: integer("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  name: varchar("name", { length: 100 }).notNull(),
  color: varchar("color", { length: 20 }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

export const timeBlocks = pgTable("time_blocks", {
  id: serial("id").primaryKey(),
  userId: integer("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  startTime: timestamp("start_time", { withTimezone: true }).notNull(),
  endTime: timestamp("end_time", { withTimezone: true }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

export const activity_allocations = pgTable("activity_allocations", {
  id: serial("id").primaryKey(),
  timeBlockId: integer("time_block_id")
    .notNull()
    .references(() => timeBlocks.id, { onDelete: "cascade" }),
  activityId: integer("activity_id")
    .notNull()
    .references(() => activities.id, { onDelete: "cascade" }),
  percentage: integer("percentage").notNull(),
});

export const pomodoroPlans = pgTable("pomodoro_plans", {
  id: serial("id").primaryKey(),
  userId: integer("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  status: varchar("status", { length: 30 }).notNull().default("focus"),
  currentPhase: varchar("current_phase", { length: 30 }).notNull().default("focus"),
  currentSession: integer("current_session").notNull().default(1),
  totalSessions: integer("total_sessions").notNull().default(4),
  focusDurationSeconds: integer("focus_duration_seconds").notNull().default(1500),
  shortBreakDurationSeconds: integer("short_break_duration_seconds").notNull().default(300),
  longBreakDurationSeconds: integer("long_break_duration_seconds").notNull().default(900),
  longBreakInterval: integer("long_break_interval").notNull().default(4),
  autoStartBreaks: boolean("auto_start_breaks").notNull().default(false),
  autoStartFocus: boolean("auto_start_focus").notNull().default(false),
  phaseStartedAt: timestamp("phase_started_at", { withTimezone: true }),
  phaseEndsAt: timestamp("phase_ends_at", { withTimezone: true }),
  pausedAt: timestamp("paused_at", { withTimezone: true }),
  pausedRemainingSeconds: integer("paused_remaining_seconds"),
  totalFocusSeconds: integer("total_focus_seconds").notNull().default(0),
  totalBreakSeconds: integer("total_break_seconds").notNull().default(0),
  totalPausedSeconds: integer("total_paused_seconds").notNull().default(0),
  completedSessions: integer("completed_sessions").notNull().default(0),
  taskId: varchar("task_id", { length: 255 }),
  taskTitle: varchar("task_title", { length: 255 }),
  startedAt: timestamp("started_at", { withTimezone: true }).defaultNow().notNull(),
  completedAt: timestamp("completed_at", { withTimezone: true }),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});
