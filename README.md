# CRON

The library was designed for PostgreSQL installed on Linux systems, which have a built-in CRON mechanism

## Installation

On your server create a CRON user and a CRON_ROLE role
```sql
CREATE ROLE cron WITH LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD 'cron';
ALTER ROLE cron SET search_path TO "$user", public;
```
```sql
CREATE ROLE cron_role WITH NOLOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
```

The CRON user will have full access to functions, tables and views.

The CRON_ROLE role is used to give users the right to insert tasks, edit and view logs.

Make sure you have extensions installed:
* dblink - provides autonomous transactions
* plperlu - allows you to run commands in the system console

With the `psql` program provided with the PostgreSQL database run the `dist/cron.sql` file. It will create the CRON schema and insert all the necessary objects.

The mechanism must be able to execute user tasks. This can be done in two ways:
1. Users add tasks within the CRON role (see the add function, arole parameter). CRON must then have the rights to execute the user function, and the function itself within the CRON user must have access to its tables. This can be done by setting the function being executed as `SECURITY DEFINER`
2. Users add tasks within their user. You must then ensure that the mechanism can switch to it by issuing the `GRANT USER TO CRON` command. Then the user function will be executed within its rights.

Previously created CRON tasks will be safe. You will still be able to edit them from the console and they will not be visible to users. Tasks inserted from the database level are specially marked in CRON.

**Update the `crtl` table. It contains the cron user password.**

## General information

The "cron" schema contains functions for managing the cron mechanism, which is responsible for running user-defined functions at specific times and their cyclicity. The schema also contains a log of completed tasks and one dictionary table for the values ​​returned by the cronalter() function.

Cron is a Unix daemon that deals with cyclic invocation of other programs. For the needs of PostgreSQL, it was used to invoke SQL commands and for single, non-periodic invocations and non-standard invocations not supported by the mechanism itself (quarter, third Saturday of the month, etc.).

Definicja zadania w crontab:
```
# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) or jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) 
# |  |  |  |  |            or sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name command to be executed
```

An asterisk (*) means to execute all values, e.g. "*" in the month column means that the task will be executed every month.

Parameters can be separated by commas, e.g. 1,3,6,16. If we write the hour parameter this way, the tasks will be executed at 01:00 at night, 03:00, 06:00 and 16:00.

Numeric parameters can also accept intervals written as an interval (with a dash) such as 1-5, which also means the same as 1,2,3,4,5.

It is also possible to specify a range, which is defined by a slash (/) character, e.g. 1-15/2 will mean the same as 1,3,5,7,9,11,13,15.

## Identifier sequence

The CRON schema contains a job_seq sequence from which the next task identifier inserted into cron is taken. This sequence works well when there is only one database with the CRON mechanism implementation on one server.

In the case where there are more databases, you should use the global numbering, which is implemented in the CRON mechanism for PostgreSQL. To run the mechanism, you should create a cron_id.seq file in the PostgreSQL home directory ./N.X/data and save the first value of the sequence in it, e.g. 1. From that moment on, all task identifiers in all databases will be assigned from the global sequence.

If you have administrator rights, you can also run the following command:
```sql
do $$
begin
  perform cron._w_cron_id_seq('NNN');
end; $$
```
This command will write the NNN value to the appropriate file. NNN is the last sequence value from all databases.

## Examples

```sql
-- Adding a task to cron. The task will be executed every month on the 6th of the month at 15:30.
select cron.add('perform public.test_function(''some_param'')', '30', '15', '6');
```

```sql
-- The following example demonstrates how to add a log cleanup task. This task will be executed every day at 0:15.
do $$
begin
  perform add('perform clear_log()', '15', '0');
end;
```

See function [documentation](doc/cron_pl.md)
