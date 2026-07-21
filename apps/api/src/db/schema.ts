import { integer, pgTable, serial, timestamp, varchar, text } from "drizzle-orm/pg-core";

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
