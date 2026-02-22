
SotA - State of the Art
=======================

DKP (Dragon Kill Points) management addon for World of Warcraft 1.12 (Vanilla).
Successor to GuildDKP, SotA provides a complete auction system, automatic boss
DKP distribution, transaction logging, and external app integration.

Version: 2.0.0
Author:  Raven
Framework: Ace 2.0


Installation
------------
Drop the SOTA folder into Interface/AddOns/ and reload the game client.
No build step required.

DKP values are stored in guild notes (officer or public, configurable)
and persisted across sessions via SavedVariables (SOTADB).


Features
--------

1. Loot Auctions
   Start an auction by shift-clicking an item into the command line:
       /sota <item link>
   The auction follows a state machine (STARTING > RUNNING > PAUSED > COMPLETE)
   with a configurable timer (7s default, extended on each new bid).
   Bids support MS (Main Spec) and OS (Off Spec) with MS priority.
   Minimum bid: 10 DKP.

2. DKP Operations
   - Individual: add or subtract DKP from a single player.
   - Raid-wide: add or subtract DKP to the entire raid.
   - Penalty: subtract a percentage of a player's DKP.
   - Decay: subtract a percentage of DKP from every guild member.
   All DKP writes run asynchronously through a background job queue.

3. Boss Kill Tracker
   Automatically detects boss kills via combat log messages and offers to
   distribute the configured DKP. Boss DKP values are importable as JSON
   through the configuration UI.
   Supported raids: Blackwing Lair, Ahn'Qiraj, Naxxramas, Emerald Sanctum,
   Upper Karazhan Halls.

4. Transaction Log
   Full history of every DKP operation (boss kills, auctions, manual changes,
   raid movements, decays). Each entry can be expanded to see affected players.
   Active transactions can be rolled back. Paginated with 24 entries per page.

5. Previous Auctions
   Browsable history of all past auctions with item, boss, winner, final bid,
   bid type, and officer. Supports rollback of individual auctions.

6. Import / Export
   - Import to Exec: batch DKP operations via JSON ({ player, dkpChange, type }).
   - Guild Extract: export guild roster with DKP as a formatted table.
   - Raven Logs: export DKP transactions and auctions as JSON for the
     RavenApp web companion.

7. Minimap Button
   Draggable button on the minimap. Left-click opens the Dashboard,
   right-click opens the configuration.


Interface
---------

Dashboard (shown during raids):

    +--------------------------------------------------------------+
    |  [coin] Ragnaros killed - Share 50 DKP               [x]     |
    |--------------------------------------------------------------|
    |  [Log] [Prev]          SOTA             [Raven] [Clear] [Cfg]|
    |                  NOT RL!    NOT ML!                          |
    +--------------------------------------------------------------+
    |  [icon] Sulfuras, Hand of Ragnaros                           |
    |         Prio: Melee DPS > Tanks                              |
    |         Notes: Legendary weapon                              |
    |--------------------------------------------------------------|
    |  [icon] Perdition's Blade                                    |
    |         Prio: Rogues                                         |
    +--------------------------------------------------------------+

    [Log]    Open the Transaction Log
    [Prev]   Browse previous auctions
    [Raven]  Export logs for RavenApp
    [Clear]  Start a new logging session
    [Cfg]    Open the configuration screen
    Loot rows are clickable to start an auction.
    Boss DKP row appears after a tracked boss kill.


Auction Window (760 x 495):

    +==============================================================+
    |                    SotA Auction Window                       |
    +------------------------------+-------------------------------+
    |                              |  Select Raid and Boss         |
    |  [ Perdition's Blade ]       +-------------------------------+
    |  Prio: Rogues                |  Blackwing Lair               |
    |  Notes: Best rogue MH        |  Ahn'Qiraj                    |
    |  [icon]                      |  Naxxramas                    |
    |                              |  Emerald Sanctum              |
    +------------------------------+  Upper Karazhan Halls         |
    |  Bidder     Type   Bid  Info |                               |
    |------------------------------+-------------------------------+
    |  Raven       MS    250  Rog  |  Razorgore the Untamed        |
    |  Sotason     MS    200  Rog  |  Vaelastrasz the Corrupt      |
    |  Mimma       OS    100  War  |  Broodlord Lashlayer          |
    |                              |  Firemaw                      |
    |                              |  Ebonroc                      |
    |                              |  Flamegor                     |
    +------------------------------+  Chromaggus                   |
    | > Raven       MS    250  Rog |  Nefarian                     |
    +------------------------------+  Trashs                       |
    |                              |                               |
    | [Pause] [Finish] [Restart]   |                               |
    | [Declare Winner] [Cancel]    |                               |
    +------------------------------+-------------------------------+

    Left panel: item info, bid list, selected bid, and action buttons.
    Right panel: raid and boss selector (sets boss name on the auction log).
    Click a bid to select it. [x] button removes the selected bid.


Command Line Reference
----------------------
All commands use the /sota prefix.

DKP Queries:
  /sota dkp [player]       Show a player's DKP (default: yourself)
  /sota class [class]      Show top 10 DKP for a class

Individual DKP:
  /sota +<n> <player>      Add <n> DKP to a player
  /sota -<n> <player>      Subtract <n> DKP from a player

Raid DKP:
  /sota raid +<n>          Add <n> DKP to everyone in the raid
  /sota raid -<n>          Subtract <n> DKP from everyone in the raid
  /sota decay <n>%         Remove <n>% DKP from every guild member

Auctions:
  /sota <item link>        Start an auction for the item

Miscellaneous:
  /sota config             Open the configuration UI
  /sota version            Display the addon version
  /sota test               Run the built-in unit tests
  /sota help               Display the help page


Configuration
-------------
Accessible via /sota config or minimap button (right-click).

  - Disable Dashboard: hide the dashboard during raids.
  - Debug mode: toggle debug output.
  - Boss DKP List: import/export boss names and DKP values (JSON).
  - Item Priorities: import loot priority rules per item (JSON).
