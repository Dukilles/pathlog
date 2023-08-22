# Pathlog

Author: Duke
Version 1.0
Pathlog is a tool to log the path of a mob, npc, or player. Its primary purpose is recording the path of a mob or npc for use in a script. The output
can be customized to the desired format, then copied to the clipboard for pasting into a script. The mode of capture can be set to either use
the player's cursor target or player can create a list. Be sure to read and understand the settings, then adjust them to fit your project before starting
path logging. Player *must* be in the same zone and close enough to receive an incoming packet (close enough
to see a red dot on FFXIDB minimap in my experience).

### Install and Load

Download, extract to addons folder, and `//lua load pathlog` in game ( or `//lua l pathlog`).

### Commands and Settings

Once loaded, the following commands are available via `//pathlog` or `//pl` for short:
(accepted abbreviations are in parentheses)

- `start(st)`             - Begins logging the path or paths of the target entity or entities.
- `stop(sp)`              - Stops logging the path or paths of the target entity or entities.
- `mode(m)`               - Changes the pathlogging "mode". Accepted arugments are `target(t)` or `list(l)`.
- `list(l)`               - Will look for an ID number argument first. If not provided, uses the ID of the targeted entity.
                          - `add(add)`  - Adds the current target to the list of targets to log. (Only works in list mode)
                          - `remove(r)` - Removes the current target from the list of targets to log.
                          - `show(s)`   - Shows the current list of targets to log.
- `all(a)`                - Toggle true/false. When true log every point with no filtering (Approximately 5 positions every 2 seconds).
- `diff(d)`               - `cumulative(c)` - Change the value of the cumulative difference setting.
                          - `x`             - Change the value of the x difference setting.
                          - `y`             - Change the value of the y difference setting.
                          - `z`             - Change the value of the z difference setting.
- `timestamp(ts)`         - Toggle true/false. When true, adds a timestamp to each line of the log.
- `tablepoints(tp)`       - Toggle true/false. When true, adds open and close brackets around each point.
- `definecoordinates(dc)` - Toggle true/false. When true, adds `x = , y = , z = ` to the coordinates in the log.
- `point(p) ...`          - Adds a point to the logs with any further arguments as a comment.

Pathlog will use the following folder structure for mobs and npcs:
- `pathlog/data/playerName/zoneName/mobName/[mobIndex]mobID.log`

Pathlog will use the following folder structure for self targeted path logs:
- `pathlog/data/playerName/zoneName/playerName.log`

Pathlog will use the following settings (adjusted with commands above) to determine if a point should be logged:
When a point is received, it is compared to the previous point. The cumulative difference is the total difference between the current point and the previous point. If the cumulative difference is greater than the cumulative difference setting, the point is logged. If the cumulative difference is less than the cumulative difference setting, the x, y, and z differences are compared to their respective settings. If any of the differences are greater than their respective settings, the point is logged. If none of the differences are greater than their respective settings, the point is not logged. If the `all` setting is true, the point is logged regardless of the above calculations.

#### Default Settings
- Default Mode: Target
- Default Message Color: 219 (must be changed in settings.xml if desired)
- Default Timestamp: True
- Default Timestamp Format: %H:%M:%S (must be changed in settings.xml if desired)
- Default Table Points: False
- Default Define Coordinates: False
- Default All: False
- Default Cumulative Difference: 4
- Default X Difference: 3
- Default Y Difference: 0.5
- Default Z Difference: 3

### Examples
- `//pl timestamp`    : 123.456, 7.890, 123.456,   -- 01:23:42
- `tablepoints`       : {123.456, 7.890, 123.456},
- `definecoordinates` : x = 123.456, y = 7.890, z = 123.456,
- `point comment`     : 123.456, 7.890, 123.456, -- comment

##### Change Log
- v1.0 22 Aug, 2023
    -- Initial release
