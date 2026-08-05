-----Users table:-


Each row represents one Chronolog account.

It stores:
- Google identity
- Profile
- Tracking state
- User settings
- Google OAuth credentials

Everything in Chronolog belongs to exactly one user.
Every table is linked by this user primary key.







--------Activities table:-

Each row is one activity created by a user.

Examples:

DSA
Japanese
Gym
Work

The table stores the catalogue of activities that can later be used inside logged time blocks.


--------TimeBlocks table:-

Each row represents one logging session.

Example:

2:00 PM

↓

3:15 PM

The table stores WHEN time passed.

It does NOT store WHAT happened during that time.





--------Activity_allocations table:-

2PM → 3PM

↓

Activity Allocations

↓

DSA 70%

Japanese 30%





--------Sessions

Each row represents one active login.

Purpose:

Maps a session cookie

↓

to a user.

Without this table

the backend cannot remember who is making requests.






OUR_IMP_FLOW:-
Users(Owns) :-Activities
             -TimeBlocks -------> TimeBlocks(contain):-Activity_allocations  
             -Sessions                                         |
                                                        point to = Activities