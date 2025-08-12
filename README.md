# Quest Weaver for Godot 4

![Quest Weaver Banner](https://raw.githubusercontent.com/undomick/godot_quest_weaver/main/docs/media/logo_banner_questWeaver.png)

**Quest Weaver** is a powerful, flexible, and node-based quest editor plugin for Godot 4.4+. Designed from the ground up to be both user-friendly for designers and easily extensible for developers, it provides a complete solution for creating complex narratives and dynamic gameplay objectives directly within the Godot editor.

Stop juggling dictionaries and hard-coded logic. Start weaving your story, one node at a time.

## Table of Contents

-   [Core Features](#core-features)
-   [Why Use Quest Weaver?](#why-use-quest-weaver)
-   [A Tour of the Node System](#a-tour-of-the-node-system)
	-   [Flow Control](#flow-control)
	-   [Logic & Game State](#logic--game-state)
	-   [World Interaction](#world-interaction)
-   [Built-in Tools for a Smooth Workflow](#built-in-tools-for-a-smooth-workflow)
-   [Installation](#installation)
-   [Getting Started](#getting-started)
-   [License](#license)

## Core Features

*   **Visual, Node-Based Editor:** Design and visualize your quest logic with an intuitive graph editor. No more getting lost in complex scripts.
*   **Powerful Flow Control:** Create branching narratives with conditional logic (`Branch`), run tasks in parallel (`Parallel`), introduce randomness (`Random`), or wait for multiple quest lines to converge (`Synchronize`).
*   **Dynamic Objectives:** Craft engaging tasks for the player, from collecting items and killing enemies to interacting with specific objects and visiting locations.
*   **Seamless Game State Integration:** Read and modify game variables directly from your quests, allowing for truly dynamic and reactive storytelling. For example, unlock a door only if the player has `strength > 10`.
*   **Event-Driven Logic:** Fire global events from your quests to trigger anything in your game world, or have quests pause and listen for events fired *from* your game world.
*   **Integrated Validator:** Catch logical errors like dead-end branches or infinite loops before they ever make it into your game.
*   **Runtime Debugger:** See your quest graphs execute in real-time as you play, with live highlighting of active and completed nodes.
*   **Extensible by Design:** A clean adapter-based system makes it easy to connect Quest Weaver to your existing inventory, UI, or other core game systems without modifying the plugin's code.

## Why Use Quest Weaver?

Quest Weaver is built on a simple philosophy: **empower the designer without limiting the developer.**

-   For **Writers and Designers**, it provides a visual canvas to build stories and quests as fast as you can imagine them. You can test different narrative paths, add conditional dialogue, and manage complex quest states without writing a single line of code.
-   For **Programmers**, it offers a robust, decoupled framework that cleanly separates quest logic from your core game code. Integrating your existing systems is straightforward, and the modular node-based architecture makes it easy to add custom nodes for project-specific needs.

## A Tour of the Node System

The heart of Quest Weaver is its rich library of nodes, each performing a specific task. Here are just a few examples:

#### Flow Control

-   **Branch Node:** The core of your narrative choices. It checks a list of conditions (e.g., *Is the player's level > 5? AND Do they have the 'King's Amulet'?*) and routes the quest down a `True` or `False` path.
-   **Parallel Node:** Fire multiple quest branches simultaneously. Send the player to talk to the blacksmith *and* the alchemist at the same time.
-   **Synchronize Node:** Wait for multiple branches to complete before continuing. The gate only opens once the player has spoken to both the blacksmith *and* the alchemist.
-   **Random Node:** Introduce chance into your quests. Will the player find a treasure map or an angry goblin? You decide the odds.

#### Logic & Game State

-   **Quest Context Node:** The entry point of every quest. Define its ID, title, description, and whether it's a main or side quest.
-   **Quest Manipulator Node:** Change the state of other quests. Completing "The Initiation" can automatically start "A New Assignment" or fail "The Rival's Plan".
-   **Set Variable Node:** Modify your game's state directly. Give the player 100 gold, increase their "chaos" stat, or set the `is_bridge_repaired` variable to `true`.

#### World Interaction

-   **Task Node:** The workhorse of your quests. Contains a list of objectives the player must complete, such as `ITEM_COLLECT`, `KILL`, or `INTERACT`.
-   **Give/Take Item Node:** Directly add or remove items from the player's inventory, with success and failure outputs.
-   **Event Listener Node:** Pause the quest until a specific game event occurs, like the player pressing a button or a day/night cycle completing.
-   **Show UI Message Node:** Display animated messages, instructions, or area titles on the screen, with full control over timing and animations.

## Built-in Tools for a Smooth Workflow

-   **Properties Panel:** A clean, context-sensitive UI to edit the properties of any selected node.
-   **Quest Validator:** A dedicated dock that scans your active quest for logical errors, unreachable nodes, and unconfigured properties, letting you jump directly to the problem node.
-   **Localization Scanner:** A one-click tool to scan all your quests for player-facing text and export new keys to a CSV file, ready for translation.

## Installation

1.  Navigate to the **Releases** page on this GitHub repository.
2.  Download the latest `QuestWeaver-vX.X.X.zip` file.
3.  Unzip the file and copy the `addons/quest_weaver` directory into your Godot project's root folder.
4.  In Godot, go to **Project -> Project Settings -> Plugins** and enable the "QuestWeaver" plugin.

## Getting Started

1.  Activate the plugin (see above).
2.  Open the Quest Weaver main view by clicking the "Quest Weaver" tab at the top of the editor.
3.  Use the side panel to create your first new quest file (`*.quest`).
4.  Right-click in the graph editor to add your first node! A good starting point is `Start Node -> Quest Context Node -> End Node`.
5.  Explore the included example scenes and quests in the `addons/quest_weaver/examples` directory to see it in action.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
