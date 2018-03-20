module deadcode.gui.controls.tabwidget;

import deadcode.gui.controls.button;
import deadcode.gui.event;
import deadcode.gui.label;
import deadcode.gui.layouts.directionallayout;
import deadcode.gui.layouts.gridlayout;
import deadcode.gui.style;
import deadcode.gui.widget;

import deadcode.core.signals;

class TabButton : ButtonBase
{
	bool isOn = false;
	mixin Signal!(TabButton) onActivated;

	enum _classes = [["on"],["off"]];

	override protected @property const(string[]) classes() const pure nothrow @safe
	{
		return _classes[isOn ? 0 : 1];
	}

	this(string text)
	{
		super(text);
	}

	override protected void activate()
	{
		if (!isOn)
        {
            isOn = true;
		    recalculateStyle();
		    onActivated.emit(this);
        }
	}
}

class TabWidget : Widget
{
    private
    {
        Widget _tabSelector; // Container of the Buttons that is used to select active tab
        GridLayout _tabSelectorLayout;
        Widget _tabView;     // Container of all the tabbed content in a stacked layout
        int _currentIndex = -1;   // -1 means no current
    }

    // (oldIndex, newIndex)
    mixin Signal!(int,int) onCurrentIndexChanged;
        
    @property 
    {
        int currentIndex()
        {
            return _currentIndex;
        }
        
        void currentIndex(int index)
        {
            if (index >= _tabSelector.children.length)
                index = _tabSelector.children.length - 1;
            
            if (index == currentIndex)
                return;

            if (index < 0)
                index = 0;

            foreach (c; _tabView.children)
                c.hide();
            
            _tabView.children[index].show();

            int old = _currentIndex;
            _currentIndex = index;

            auto oldButton = getTabButton(old);
            if (oldButton !is null)
                oldButton.isOn = false;

            auto currentButton = getTabButton(index);
            currentButton.activate();

            onCurrentIndexChanged.emit(old, index);
        }
        
        size_t length() const pure nothrow @safe
        {
            return _tabSelector.children.length;
        }
        
        bool empty() const pure nothrow @safe
        {
            return _tabSelector.children.length != 0;
        }
    }

    this()
    {
        _tabSelector = new Widget(this);
        _tabSelector.name = "tab-selector";
        _tabSelectorLayout = new GridLayout(GridLayout.Direction.row, 1);
        _tabSelector.layout = _tabSelectorLayout;
        _tabView = new Widget(this);
        _tabView.name = "tab-view";
        _tabView.styleOverride.position = CSSPosition.relative;
        styleOverride.position = CSSPosition.relative;
        layout = new DirectionalLayout!false();
    }

    Widget opIndex(int index)
    {
        return getTab(index);
    }
    
    Widget getTab(int index)
    {
        if (index >= _tabView.children.length || index < 0)
            return null;
        return _tabView.children[index];
    }

	Widget getCurrentTab()
    {
		return getTab(_currentIndex);
    }

    private TabButton getTabButton(int index)
    {
        if (index >= _tabSelector.children.length || index < 0)
            return null;
        return cast(TabButton) _tabSelector.children[index];
    }

    void setLabel(int index, string label)
    {
        auto b = getTabButton(index);
        if (b is null)
            return;
    
        b.text = label;
    }

    int addTab(Widget w, string label)
    {
        return insertTab(int.max, w, label);
    }

    int insertTab(int index, Widget w, string label)
    {
        if (index < 0)
            index = 0;
        
        auto childCount = _tabSelector.children.length;
        if (index > childCount)
            index = childCount; // clamp

        auto tabButton = new TabButton(label);
        tabButton.onActivated.connectTo((TabButton b) {
            currentIndex = index;
        });

        if (_tabSelector.children.length == 0)
            tabButton.isOn = true;
        
        tabButton.name = label;
        tabButton.parent = _tabSelector;
        w.parent = _tabView;

        _tabSelector.moveChildToIndex(_tabSelector.children.length - 1, index);
        _tabView.moveChildToIndex(_tabView.children.length - 1, index);

        if (currentIndex == -1)
            currentIndex = index;

        _tabSelectorLayout.setFixedColumn(index, 100);

        return index;
    }

    void removeTab(int index)
    {
        if (index >= _tabView.children.length || index < 0)
            return;
        getTab(index).parent = null;
        auto b = getTabButton(index);
        if (b.isOn)
        {
            if (index > 0)
                getTabButton(index-1).activate();
            else if (index < _tabSelector.children.length - 1)
                getTabButton(index+1).activate();
        }
        getTabButton(index).parent = null;
    }
}
