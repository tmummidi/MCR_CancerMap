// custom crafted control for this one project
// a legend control to select a choropleth rendering. this just offers a UI to select which choropleth to use
// see performSearchMap() which really does the work of generating the choropleth
L.Control.ChoroplethLegend = L.Control.extend({
	options: {
		position: 'topright',
        expanded: false,
		selectoptions: [],  // see index.js CHOROPLETH_OPTIONS
        onChoroplethChange: function () {},
	},
	initialize: function(options) {
		L.setOptions(this,options);
	},
	onAdd: function (map) {
		this._map = map;

		// create our container
		this.container = L.DomUtil.create('div', 'leaflet-control leaflet-bar leaflet-choroplethlegend-control leaflet-choroplethlegend-collapsed');
		this.content_collapsed = L.DomUtil.create('div', 'leaflet-choroplethlegend-button', this.container);
		this.content_expanded = L.DomUtil.create('div', 'leaflet-choroplethlegend-content', this.container);

        // our closed state: a button to open
		this.content_collapsed.innerHTML = '<i class="fa fa-bars"></i>';

        // expanded content

        // close button
        this.closebutton = L.DomUtil.create('i', 'leaflet-choroplethlegend-closebutton', this.content_expanded);
        this.closebutton.innerHTML = '&times;';

        // head text
        this.headtext = L.DomUtil.create('div', 'leaflet-choroplethlegend-headtext', this.content_expanded);
        this.headtext.innerHTML = 'Color By';

        // the choropleth-by-what-field selector and its optioons, driven by this.options.selectoptions
        this.selector = L.DomUtil.create('select', 'leaflet-choroplethlegend-select', this.content_expanded);
		this.selector.setAttribute('aria-label', 'Select how to color the map');
		this.options.selectoptions.forEach((vizopt) => {
			const option = L.DomUtil.create('option', '', this.selector);
			option.innerHTML = vizopt.label;
			option.value = vizopt.field;
		});

        // the gradient legend and the min/max value words
        this.legendgradient = L.DomUtil.create('div', 'leaflet-choroplethlegend-legendgradient', this.content_expanded);
        this.legendminvalue = L.DomUtil.create('div', 'leaflet-choroplethlegend-minvalue', this.content_expanded);
        this.legendmaxvalue = L.DomUtil.create('div', 'leaflet-choroplethlegend-maxvalue', this.content_expanded);

		// stop mouse events from falling through (Leaflet 1.x)
        L.DomEvent.disableClickPropagation(this.container);
        L.DomEvent.disableScrollPropagation(this.container);

		// click X to close & click closed version to open
        // ARIA/508 translate hitting enter as clicking
		L.DomEvent.addListener(this.content_collapsed, 'keydown', (event) => {
            if (event.keyCode == 13) this.content_collapsed.click();
		});
		L.DomEvent.addListener(this.closebutton, 'keydown', (event) => {
            if (event.keyCode == 13) this.closebutton.click();
		});

		L.DomEvent.addListener(this.content_collapsed, 'click', () => {
			this.expand();
		});
		L.DomEvent.addListener(this.closebutton, 'click', () => {
			this.collapse();
		});
        if (this.options.expanded) {
            setTimeout(() => {
                this.expand();
            }, 0.5 * 1000);
        }

		// enable keyboard interactions
        if (this._map.options.keyboard) {
            this.content_collapsed.tabIndex = 0;
            this.closebutton.tabIndex = 0;
        }

        // when the selector is changed, call the suppled callback
        L.DomEvent.addListener(this.selector, 'change', () => {
            const field = this.getSelection();
            this.options.onChoroplethChange(field);
        });

		// all done
		return this.container;
	},
	expand: function (html) {
		L.DomUtil.addClass(this.container, 'leaflet-choroplethlegend-expanded');
		L.DomUtil.removeClass(this.container, 'leaflet-choroplethlegend-collapsed');
	},
	collapse: function (html) {
		L.DomUtil.removeClass(this.container, 'leaflet-choroplethlegend-expanded');
		L.DomUtil.addClass(this.container, 'leaflet-choroplethlegend-collapsed');
	},
    getSelection: function () {
        const value = this.selector.options[this.selector.selectedIndex].value;
        return value;
    },
	getSelectionLabel: function () {
        const text = this.selector.options[this.selector.selectedIndex].innerHTML;
        return text;
	},
	setSelection(newvalue) {
		// see also the event listener that makes stuff happen
		this.selector.value = newvalue;

		var event = new Event('change');
		this.selector.dispatchEvent(event);
	},
    setMinMax: function (minvalue, maxvalue) {
        this.legendminvalue.innerHTML = minvalue;
        this.legendmaxvalue.innerHTML = maxvalue;
    },
	setGradientColors: function (colorlist) {
		const csscolor = `linear-gradient(to right, ${colorlist.join(', ') })`;
		this.legendgradient.style.backgroundImage = csscolor;
	},
	setPrintMode: function (printmodeon) {
		// highly contrived to this use case: CSS rules exist to suppress and alter some elements when in "print mode"
		if (printmodeon) {
			L.DomUtil.addClass(this._container, 'leaflet-choroplethlegend-printmode');
		}
		else {
			L.DomUtil.removeClass(this._container, 'leaflet-choroplethlegend-printmode');
		}
	},
});
