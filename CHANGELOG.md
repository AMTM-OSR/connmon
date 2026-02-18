# Changelog

## v3.0.11
Updated on 2026-Feb-18
*   NEW: Added code to support automatic add-on updates from AMTM.

## v3.0.10
Updated on 2025-Dec-21
*   FIXED: Bug fix in a CLI shell script function to get the full value of notification parameters from the configuration file.
*   FIXED: Bug fix in a WebUI JS function to get the full value of notification parameters from the configuration file.
*   FIXED: Modified the curl command sending data to InfluxDB so that it conforms to new API requirements and the proper database schema structure.
*   FIXED: Modified WebUI text message to show default interval of 5 minutes. Functionality was correct. This is just a correction to the text string.
*   NEW: Added new "InfluxDB Organization" parameter to WebUI page and CLI menu. This parameter is now required to send data to InfluxDB.
*   NEW: Added new "InfluxDB Protocol" parameter to WebUI page and CLI menus to specify whether to use HTTP or HTTPS protocol.
*   NEW: Added "Ping Server" and "Router Model" information to each data point being sent to InfluxDB.
*   NEW: Added "Ping Server" and "Router Model" information to all Pushover and Email notifications.
*   IMPROVED: Modified the CLI top Main Menu to separate some groups of options and settings into their own sub-menus. This is an effort to make the top Main Menu shorter, more manageable, more user-friendly, and to improve the user experience.
*   Miscellaneous code improvements.

## v3.0.9
Updated on 2025-Nov-27
*   FIXED: In some rare situations, the setting for the ping test server IP address went "missing" from the configuration file, and the value could no longer be modified by the user.
*   FIXED: In some rare situations, the setting for the automatic ping test time schedule went "missing" from the configuration file, and the value could no longer be modified by the user.
*   MODIFIED: Upon a fresh installation, the default setting for the automatic ping test time schedule is now set to every 5 minutes instead of every 3 minutes.

## v3.0.8
Updated on 2025-Nov-16
*   NEW: Additional "Notification Event Type" to set up notifications and run custom user scripts when a ping test fails.
*   NEW: Added "Ping Test Failure" events to the results shown on the WebUI page.
*   IMPROVED: Modified code to make sure we get correct parameters when changing settings from the WebUI.
*   IMPROVED: Miscellaneous code improvements.

## v3.0.7
Updated on 2025-Nov-08
*   IMPROVED: Modified code to re-initialize global parameters after USB-attached drive has been mounted and Entware is found.
*   IMPROVED: More checks to clean up files when switching from JFFS to USB and vice versa.
*   MODIFIED: Removed old Tomato JavaScript file references.
*   IMPROVED: Miscellaneous code improvements.

## v3.0.6
Updated on 2025-July-21
*   FIXED: Added code to check for return status of the ping test command and to verify all the required data is found in the results.
*   FIXED: Missing symbolic link needed to show a summary of the ping test results on the WebUI page.
*   IMPROVED: Added a delay after stopping and then later after restarting QoS (if enabled) to allow the operation to be completed before initiating a ping test.
*   IMPROVED: Added log messages when stopping and later restarting QoS (if enabled).
*   IMPROVED: Miscellaneous code improvements.

## v3.0.5
Updated on 2025-June-21
*   FIXED: New code to remove duplicate parameter key names found in the configuration file. Getting duplicate key values can cause "bad number" or "arithmetic syntax" errors.
*   IMPROVED: New code to create a separate logfile to capture the SQLite3 errors with more verbosity.
    Debug logfile default location: /opt/share/tmp/
*   IMPROVED: Added error-handling code when an SQLite3 database operation fails to create a file. 
*   IMPROVED: When an SQLite3 operation returns error messages indicating a corrupted binary, the error-handling code will now log a separate message to the system logger and to its own debug logfile to let users know of the corrupted SQLite3 and the need to remove and reinstall its Entware package.
*   IMPROVED: Miscellaneous code improvements.

## v3.0.4
Updated on 2025-May-25
*   Moved to AMTM-OSR repo
*   Changed repo paths to OSR, added OSR repo to headers, removed jackyaz.io tags in URL.

## v3.0.3
Updated on 2025-Feb-18
*   FIXED: Errors when loading the webGUI page on the 3006.102.1 F/W version.
*   FIXED: Bug giving incorrect results when computing the free space available of a large-capacity USB-attached drive. This was preventing the user from resetting the database using the CLI menu.
*   FIXED: "Reset Database" functionality on the CLI menu was correctly resetting the database file but the result was not reflected on the webGUI page where "old" entries were still shown as if the database had not been reset.
*   IMPROVED: Modified all SQLite3 calls to capture and log errors in the system log.
*   IMPROVED: Modified SQLite3 configuration parameters to improve the trimming of records from the database and then perform "garbage collection" of deleted entries to reclaim unused space & avoid excessive fragmentation.
*   IMPROVED: Modified SQLite3 configuration parameters to improve the processing of database records.
*   IMPROVED: Modified code to set the corresponding priority level of log entries when calling the built-in logger utility.
*   IMPROVED: Modified the startup call made in the post-mount script to check if the USB-attached disk partition passed as argument has Entware installed.
*   IMPROVED: Added code to show the current database file size information on the CLI menu and the webGUI page.
*   IMPROVED: Added code to show the "JFFS Available" space information for the "Data Storage Location" option on the CLI menu and the webGUI page.
*   IMPROVED: Added code to check if sufficient JFFS storage space is available before moving database-related files/folders from USB location to JFFS partition. An error message is reported if not enough space is available, and the move request is aborted.
*   IMPROVED: Added code to check if the available JFFS storage space falls below 20% of total space or 10MB (whichever is lower) and report a warning when it does. A warning message is also shown on the SSH CLI menu and WebGUI page.
*   IMPROVED: Added and modified code so that every time the SSH CLI menu is run, it checks if the WebGUI page has already been mounted. If not found mounted, the script will run the code to remount the WebGUI.
*   IMPROVED: Improved code that creates (during installation) and removes (during uninstallation) the "AddOns" menu tab entry for the WebGUI to make sure it checks for and takes into account other add-ons that may have been installed before or were later installed after the initial installation.
*   IMPROVED: Added "export PATH" statement to give the built-in binaries higher priority than the equivalent Entware binaries.
*   CHANGED: Modified code related to "var $j = jQuery.noConflict();" which is now considered obsolete. 
*   IMPROVED: Various code improvements & fine-tuning.

## v3.0.2
06 January 2022
*   FIXED: Only download CHANGELOG on upgrade if it doesn't exist

## v3.0.1
05 January 2022
*   IMPROVED: Add helptext for custom actions and scripts about Apprise notification library
*   FIXED: Remove ping target validation when running ping test, it can incorrectly mask downtime - e.g. DNS is unavailable
*   CHANGED: Script now downloads updates via Scarf Gateway (see bottom of README)
*   CHANGED: Script now installs LICENSE and README files during install

## v3.0.0
28 August 2021

*   NEW: Notifications and integrations
*   NEW: Changelog displayed when updating
*   NEW: New-look WebUI page

**Notifications and Integrations**

Currently, supported mechanisms for notifications/integrations are:
*   Email
*   Discord webhook (https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks)
*   Pushover (https://pushover.net/)
*   Custom actions (write your own scripts to do whatever you'd like)
*   Healthcheck monitoring (https://healthchecks.io/)
*   InfluxDB data export (if you already run InfluxDB, you can push connmon data to it and visualize it in Grafana, for example)

There are 4 events which trigger the notifications:
*   On each ping test
*   Ping threshold exceeded
*   Jitter threshold exceeded
*   Line Quality threshold exceeded

**Email configuration**

connmon v3.0.0 marks a move to a standalone email configuration that can be utilised by other scripts. If you have Diversion installed, connmon will detect this and migrate Diversion's config to the new standalone location with is /jffs/addons/amtm/mail
connmon will create links for Diversion to follow the configuration to the above location.

## v2.11.7
4 August 2021

*   CHANGED: service-event hook is more selective when it calls connmon

## v2.11.6
23 June 2021

*   FIXED: WebUI charts using Day grouping wouldn't display data between midnight and 1am
*   FIXED: Database reset would incorrectly report disk space availability

## v2.11.5
20 June 2021

*   NEW: Automatic database analysis after adding new results and pruning old records

## v2.11.4
30 May 2021

*   IMPROVED: Line quality calculation - credit @waluwaz
*   FIXED: min/max for zoom/pan of charts

## v2.11.3
28 April 2021

*   NEW: WebUI toggle (cookie) for changing column order of Last X table

## v2.11.2
25 April 2021

*   NEW: Setting to choose whether to include ping tests in QoS or not
*   IMPROVED: Show IP used for test when using a domain to ping
*   IMPROVED: Show placeholder text in WebUI while data is loading

## v2.11.1
24 April 2021
*   FIXED: Installing for the first time would hang

## v2.11.0
22 April 2021

*   NEW: Configure how long data is kept in the database
*   NEW: Configure how many recent results are displayed in the WebUI
*   NEW: Ping target/destination and ping duration are now logged alongside ping test results
*   IMPROVED: CPU intensive tasks are now run with a lower priority to minimise hogging the CPU
*   IMPROVED: Recent ping results table in WebUI is now sortable and scrollable

## v2.10.0
17 April 2021

*   NEW: Choice of data aggregation for charts in WebUI: raw, hourly and daily
*   IMPROVED: Use of keyboard keys d,r,l,f for chart functions (drag zoom, reset zoom, toggle lines, toggle fill)
*   IMPROVED: Use of indexes in database for small performance increases
*   IMPROVED: Use ajax to load dependent files in WebUI to avoid complete page load failures if a file was unavailable
*   IMPROVED: Stale connmon processes will be cleared on each ping test
*   REMOVED: Setting toggle for raw vs. average

## v2.9.1
24 March 2021

*   FIXED: Saving schedule from WebUI
*   FIXED: Collapsing headers in WebUI after running a ping test
*   CHANGED: Cookie expiry for collapsed section increase from 31 days to 10 years

## v2.9.0
23 March 2021

*   NEW: Option to turn automatic ping tests on/off
*   NEW: CLI menu shows URL for WebUI page
*   NEW: CLI commands for about and help
*   IMPROVED: Scheduling of automatic ping tests is now much more flexible
*   IMPROVED: Update function now includes a prompt rather than applying update
*   IMPROVED: Use colours in CLI menu to highlight settings
*   CHANGED: NTP timeout increased to 10 minutes

## v2.8.5
6 March 2021

*   NEW: Add option to reset database (CLI menu only)
*   CHANGED: Allow ping frequency maximum to be every 30 minutes (up from 10)
*   CHANGED: Exclude pings from QoS instead of marking as default
*   FIXED: Print correct test length at CLI

## v2.8.4
13 February 2021

*   IMPROVED: WebUI tab mounting on reboot

## v2.8.3
20 January 2021

*   FIXED: Logarithmic scale wasn't being formatted correctly

## v2.8.2
18 January 2021

*   NEW: Option to display charts with a logarithmic scale on y-axis
*   CHANGED: Charts now use values at 2 decimal places instead of 3
*   IMPROVED: Export now produces a csv rather than a zip
*   FIXED: Last X table can now be collapsed and expanded

## v2.8.1
14 January 2021

*   CHANGED: connmon now launches on boot from post-mount not services-start

## v2.8.0
22 November 2020

*   NEW: Add WebUI table for last 10 ping tests
*   NEW: Show result of manual ping test in WebUI
*   NEW: Configure which hours connmon should run
*   IMPROVED: CSV export has been condensed to a combined csv with all available metrics
*   CHANGED: Use 7za instead of 7z (MIPS fix)
*   CHANGED: Rename Packet_Loss column in db to LineQuality to reflect actual stored values

## v2.7.1
7 November 2020

*   IMPROVED: Run ping test in WebUI with progress shown (via Ajax)

## v2.7.0
24 October 2020

*   NEW: All connmon options can be configured in the WebUI
*   NEW: Ping test duration and frequency is now user configurable
*   CHANGED: WebUI check for updates no longer needs a page refresh (thanks to @dave14305 !)
*   CHANGED: WebUI tab name is now connmon and not Uptime Monitoring
*   IMPROVED: Reduced use of lock files to make script more responsive from the WebUI
