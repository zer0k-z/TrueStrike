# TrueStrike

![Downloads](https://img.shields.io/github/downloads/zer0k-z/truestrike/total?style=flat-square) ![Last commit](https://img.shields.io/github/last-commit/zer0k-z/truestrike?style=flat-square) ![Open issues](https://img.shields.io/github/issues/zer0k-z/truestrike?style=flat-square) ![Closed issues](https://img.shields.io/github/issues-closed/zer0k-z/truestrike?style=flat-square) ![Size](https://img.shields.io/github/repo-size/zer0k-z/truestrike?style=flat-square) ![GitHub Workflow Status](https://img.shields.io/github/workflow/status/zer0k-z/truestrike/Compile%20with%20SourceMod?style=flat-square)

## Description ##
Toggle ammo, recoil, inaccuracy and spread for CS:GO. 

## Features ##
1. Inaccuracy: Same effect as ``weapon_accuracy_nospread 1``, but client sided. This is usually the main source of your total inaccuracy, with a few exceptions (R8 Revolver secondary fire for example). This value depends on your weapon, your recoil and your movement. Useful for incrasing accuracy on high inaccuracy weapon such as AWP.

2. Spread: The second source of your total inaccuracy. This differs from inaccuracy, as it only depends on the weapon stats and does not get disabled with ``weapon_accuracy_nospread 1``. Useful for increasing accuracy on high spread weapon such as R8 Revolver's secondary fire.

3. Recoil: Turn your viewmodel recoil off. This only works for weapon firing, viewmodel changes due to movement, reloading or deploying (R8/Shadow Daggers) are not disabled.

4. Bullet prediction: Server usually generates its own seed in order to calculate bullet impact. This option allow client generated bullet predictions to be correct. *However*, this will not work with spread turned off, due to prediction being client sided and spread toggle being server sided. Using cl_predict 0 disables client prediction, but this will cause extreme input delay outside of LAN servers.

5. Infinite Ammo: Similar to a client sided ``sv_infinite_ammo``, however ``sv_infinite_ammo 2`` does not take into account cases where you do not have enough bullets in reserve for a full reload. This plugin fixes the problem by always making sure that there is enough bullets to be refilled to maximum.

## Commands ##
- ``sm_truestrike`` - Open TrueStrike menu.

## Requirements ##
- Sourcemod and Metamod
- [DHooks2](https://github.com/peace-maker/DHooks2)

## Installation ##
1. Grab the latest release from the release page and unzip it in your sourcemod folder.
2. Restart the server or type `sm plugins load truestrike` in the console to load the plugin.

## Trivia ##
The plugin name is inspired by the Monkey King Bar's old passive in DotA.
