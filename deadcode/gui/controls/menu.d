module deadcode.gui.controls.menu;

import deadcode.core.command;
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

	mixin Signal!(ICommand, CommandParameter[]) onMissingCommandArguments;

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
		menuButton.zOrder = 99;
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
		auto cmd = commandManager.lookup(cc.name);
		if (cmd is null)
			return;

		auto defs = cmd.getCommandParameterDefinitions();
		CommandParameter[] params;
		if (defs is null || defs.setValues(params, cc.arguments))
			commandManager.execute(cc);
		else
			onMissingCommandArguments.emit(cmd, params);
	}
}
