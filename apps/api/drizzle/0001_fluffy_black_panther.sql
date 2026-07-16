CREATE TABLE "activity_allocations" (
	"id" serial PRIMARY KEY NOT NULL,
	"time_block_id" integer NOT NULL,
	"activity_id" integer NOT NULL,
	"percentage" integer NOT NULL
);
--> statement-breakpoint
DROP TABLE "time_block_entries" CASCADE;--> statement-breakpoint
ALTER TABLE "activity_allocations" ADD CONSTRAINT "activity_allocations_time_block_id_time_blocks_id_fk" FOREIGN KEY ("time_block_id") REFERENCES "public"."time_blocks"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activity_allocations" ADD CONSTRAINT "activity_allocations_activity_id_activities_id_fk" FOREIGN KEY ("activity_id") REFERENCES "public"."activities"("id") ON DELETE no action ON UPDATE no action;