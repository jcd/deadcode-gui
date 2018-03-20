module deadcode.gui.controls.menu;

import deadcode.command.command;
import deadcode.core.signals;
import deadcode.gui.controls.button;
import deadcode.gui.controls.tree;
import deadcode.gui.event;
import deadcode.gui.widget;
import deadcode.gui.widgetfeatures.windowdragger;

import std.stdio;
import std.typetuple;

class Menu : Tree
{
	Button menuButton;
	CommandManager commandManager;

	// (commandName, params)
	mixin Signal!(string, CommandParameter[]) onMissingCommandArguments;

	alias parent = Widget.parent;
    @property override void parent(Widget newParent) nothrow
	{
		menuButton.parent = newParent;
		super.parent = newParent;
	}

	this(CommandManager cmdMgr)
	{
        super();
		commandManager = cmdMgr;
		// Menu
		hidden = true;
		acceptsKeyboardFocus = true;
		onKeyboardUnfocusCallback = (Event ev, Widget w) {
			this.hidden = true;
			return EventUsed.yes;
		};

		//addTreeItem("Bar/Bazzimusss", "edit.scrollPageDown");
		//addTreeItem("Bar/Baxx");
		//addTreeItem("Lars");

		menuButton = new Button("Menu");

        menuButton.features ~= new WindowDragger();
		menuButton.name = "menuButton";
		menuButton.styleOverride.zIndex = 99;
		menuButton.onMouseOverCallback = (Event, Widget) {
			this.hidden = false;
			return EventUsed.yes;
		};

		menuButton.onMouseClickCallback = (Event, Widget) {
			this.hidden = !this.hidden;
			return EventUsed.yes;
		};

		treeClicked.connect(&onMenuClicked);
		commandTriggered.connect(&onCommandCall);
	}

	private void onMenuClicked(Tree t)
	{
		version (linux)
            std.stdio.writeln("Hello from " ~ t.name);
	}

	private void onCommandCall(CommandCall cc)
	{
		auto defs = commandManager.getCommandParameterDefinitions(cc.name);
		CommandParameter[] params;
		if (defs is null || defs.setValues(params, cc.arguments))
			commandManager.execute(cc);
		else
			onMissingCommandArguments.emit(cc.name, params);
	}
}
