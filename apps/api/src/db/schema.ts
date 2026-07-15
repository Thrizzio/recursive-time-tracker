import { integer, pgTable, serial, timestamp, varchar } from "drizzle-orm/pg-core";

export const activities = pgTable("activities", {
  id: serial("id").primaryKey(),
  name: varchar("name", { length: 100 }).notNull(),
  color: varchar("color", { length: 20 }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

export const timeBlocks = pgTable("time_blocks", {
  id: serial("id").primaryKey(),
  startTime: timestamp("start_time", { withTimezone: true }).notNull(),
  endTime: timestamp("end_time", { withTimezone: true }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

export const activity_allocations = pgTable("activity_allocations", {
  id: serial("id").primaryKey(),
  timeBlockId: integer("time_block_id")
    .notNull()
    .references(() => timeBlocks.id),
  activityId: integer("activity_id")
    .notNull()
    .references(() => activities.id),
  percentage: integer("percentage").notNull(),
});
