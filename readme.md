# Pathlog

- Author: Duke
- Version 2.0
- Pathlog is a tool to log the path of a mob, npc, or player. Its primary purpose is recording the path of a mob or npc for use in a script. The output
can be customized to the desired format, then copied to the clipboard for pasting into a script. The mode of capture can be set to either use
the player's cursor target or player can create a list. Be sure to read and understand the settings, then adjust them to fit your project before starting
path logging. Player *must* be in the same zone and close enough to receive an incoming packet (close enough
to see a red dot on FFXIDB minimap in my experience).

- Please feel free to shoot me a message or send a pull request if you have any suggestions or find any bugs.

### Install and Load

Download, extract to addons folder, and `//lua load pathlog` in game ( or `//lua l pathlog`).

### Commands and Settings

Once loaded, the following commands are available via `//pathlog` or `//pl` for short:
(accepted abbreviations are in parentheses)

- `start(st)`             - Begins logging the path or paths of the target entity or entities.
- `stop(sp)`              - Stops logging the path or paths of the target entity or entities.
- `mode(m)`               - Changes the pathlogging "mode". Accepted arugments are `target(t)` or `list(l)`.
- `filter(f)`             - Changes the pathlogging "filter". Accepted arugments are `xyz` or `rot`.
- `pauselegs(pl)`         - Toggle true/false. In list mode, when true auto divide mob/npc pauses into separate path legs.
- `list(l)`               - Will look for an ID number argument first. If not provided, uses the ID of the targeted entity.
  - `add(add)`            - Adds the current target to the list of targets to log. (Only works in list mode)
  - `remove(r)`           - Removes the current target from the list of targets to log.
  - `show(s)`             - Shows the current list of targets to log.
- `all(a)`                - Toggle true/false. When true log every point with no filtering (Approximately 5 positions every 2 seconds).
- `diff(d)`               - These settings are used to determine whether or not to log an incoming point.
  - `cumulative(c)`       - Change the value of the cumulative difference setting.
  - `x`                   - Change the value of the x difference setting.
  - `y`                   - Change the value of the y difference setting.
  - `z`                   - Change the value of the z difference setting.
  - `rot`                 - Change the value of the rot difference setting.
  - `time(t)`             - Change the value of the time difference setting (used only with list mode and pauseLegs).
- `rot(r)`                - Toggle true/false. When true, adds rot to each line of the log.
- `timestamp(ts)`         - Toggle true/false. When true, adds a timestamp to each line of the log.
- `tablepoints(tp)`       - Toggle true/false. When true, adds open and close brackets around each point.
- `definecoordinates(dc)` - Toggle true/false. When true, adds `x = , y = , z = ` to the coordinates in the log.
- `point(p) ...`          - Adds a point to the logs with any further arguments as a comment.

Pathlog will use the following folder structure for mobs and npcs:
- `pathlog/data/pathlogs/playerName/zoneName/mobName/mobID.log`

Pathlog will use the following folder structure for self targeted path logs:
- `pathlog/data/pathlogs/playerName/zoneName/playerName.log`

#### Filters
Pathlog will use the following settings (adjusted with commands above) to determine if a point should be logged:
When a point is received, it is compared to the previous point. Pathlog will use one of two filters to determine if the point should be logged.
##### Rot Filter
The default filter is the `rot` filter. This will evaluate the rotation of the mob/npc and the y coordinate or elevation. As the default rotDiff is 0, any rotation change will result in the point being logged. Ideally, this will filter out any points between the first and last points of a straight line.
##### XYZ Filter
The second filter setting is the `xyz` filter, which calcuates the cumulative difference between two points as well as the x difference, y difference, and z difference. The cumulative difference is the total difference between the current point and the previous point. If the cumulative difference is greater than the cumulative difference setting, the point is logged. If the cumulative difference is less than the cumulative difference setting, the x, y, and z differences are compared to their respective settings. If any of the differences are greater than their respective settings, the point is logged. If none of the differences are greater than their respective settings, the point is not logged. If the `all` setting is true, the point is logged regardless of the above calculations.

#### Dividing a path into legs
##### Target Mode
In target mode, `pauseLegs` is not used. The path is logged as a single leg, unless the user changes target. When the user changes target, Pathlog will close off the previous target's path leg with a close bracket, and begin a new path leg for the new target with an open bracket. This will allow the user to determine path legs by simply escaping the cursor off of the target then back on to it when a new leg is desired.
##### List Mode
In list mode, when `pauseLegs` is true, Pathlog will divide the path into legs based on the time difference setting, or pauses in the npc's pathing. When a point is received, Pathlog will compare the time difference between the current point and the previous point. If the time difference is greater than the time difference setting, Pathlog will recall the last point, log it if appropriate, and close off that leg with a close bracket.

#### Default Settings
- Default Mode: Target
- Default Filter: Rot
- Default pauseLegs: True
- Default Message Color: 219 (must be changed in settings.xml if desired)
- Default Timestamp: True
- Default Timestamp Format: %H:%M:%S (must be changed in settings.xml if desired)
- Default Table Points: False
- Default log Rot: False
- Default Define Coordinates: False
- Default All: False
- Default Cumulative Difference: 4
- Default X Difference: 3
- Default Y Difference: 0.5
- Default Z Difference: 3
- Default Rot Difference: 0
- Default Time Difference: 4

### Examples
- When `timestamp` is true:
  - `123.456, 7.890, 123.456,   -- 01:23:42`
- When `tablepoints` is true:
  - `{123.456, 7.890, 123.456},`
- When `definecoordinates` is true:
  - `x = 123.456, y = 7.890, z = 123.456,`
- When `rot` is true:
  - `123.456, 7.890, 123.456, 254`
- Using the command `point this is an important comment`:
  - `123.456, 7.890, 123.456, -- this is an important comment`

##### Change Log

- v1.0 27 Aug, 2023
  - Initial release

- v1.1 29 Aug, 2023
  - Add rot option to mob/npc logs

- v2.0 04 Sept, 2023
  - Add pauseLegs with timeDiff to split mob/npc path into legs by pauses
  - Add method to split path into legs by target change
  - Add ghostLog to pull from to append to end and finish a log
  - Add tabling for each leg or the entire path
