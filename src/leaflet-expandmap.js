/*
 * L.Control.ExpandMap
 * highly custom crafted for this one application's use case
 * to resize the map's containing cell (inside a Bootstrap 4 responsive grid row) and hide the left-hand cell...
 */
L.Control.ExpandMap = L.Control.extend({
    options: {
        position: 'topright',
        title: 'Expand the map to full width, or collapse it back to regular view',
    },
    initialize: function(options) {
        L.setOptions(this, options);
        this.map    = null;
    },
    onAdd: function (map) {
        // our map
        this.map = map;

        // our container and the icon
        // the icon will be changed, so keep a reference to it
        this.container = L.DomUtil.create('div', 'leaflet-control-expandmap leaflet-control-expandmap-collapsed');
        this.icon = L.DomUtil.create('i', 'fa fa-expand', this.container);
        this.textlabel = L.DomUtil.create('span', '', this.container);
        this.textlabel.innerHTML = 'Expand Map';

        if (this.map.options.keyboard) {
            this.container.tabIndex = 0;
        }

        // stop mouse events from falling through (Leaflet 1.x)
        L.DomEvent.disableClickPropagation(this.container);
        L.DomEvent.disableScrollPropagation(this.container);

        // click to toggle expanded/collapsed state
        // ARIA/508 translate hitting enter as clicking
		L.DomEvent.addListener(this.container, 'click', () => {
			this.toggle();
		});
		L.DomEvent.addListener(this.container, 'keydown', (event) => {
            if (event.keyCode == 13) this.container.click();
		});

        // done, hand back the container
        return this.container;
    },
    toggle: function () {
        if (this.container.classList.contains('leaflet-control-expandmap-collapsed')) {
            this.expandmap();
        }
        else {
            this.collapsemap();
        }
    },
    expandmap: function () {
        // toggle this icon
        this.container.classList.add('leaflet-control-expandmap-expanded');
        this.container.classList.remove('leaflet-control-expandmap-collapsed');
        this.icon.classList.remove('fa-expand');
        this.icon.classList.add('fa-compress');
        this.textlabel.innerHTML = 'Shrink Map';

        // do it
        // this is highly custom crafted to this situation:
        // a BS4 grid cell which is col-md-7 being turned into a 12 and pulled left,
        // and the LHS content in fact being MOVED into the second row, so it can come below the map; really crazy
        // but at least it's isolated to these two functions, so you should have little trouble adapting it to your own situation in some other app
        const $rightside = document.querySelector('.data-readouts-rhs');
        const $leftside = document.querySelector('.data-readouts-lhs');
        const $rightunder = $rightside.querySelector('.data-readouts-rhs-lower');
        const $stats = $rightunder.querySelector('.data-readouts-rhs-demogs');
        const $download = $rightunder.querySelector('.data-readouts-rhs-download');

        $rightside.classList.remove('col-md-7');
        $rightside.classList.add('col-12');

        $rightunder.appendChild($leftside);
        $leftside.classList.remove('col-md-5');
        $leftside.classList.add('col-lg-5');
        $leftside.classList.add('order-first');

        $stats.classList.remove('col-lg-8');
        $stats.classList.add('col-lg-5');

        $download.classList.remove('col-lg-4');
        $download.classList.add('col-lg-2');
        $download.classList.add('nowrap');

        // done; tell the map that it has changed size
        this.map.invalidateSize();
    },
    collapsemap: function () {
        // toggle this icon
        this.container.classList.add('leaflet-control-expandmap-collapsed');
        this.container.classList.remove('leaflet-control-expandmap-expanded');
        this.icon.classList.add('fa-expand');
        this.icon.classList.remove('fa-compress');
        this.textlabel.innerHTML = 'Expand Map';

        // do it
        // basically, undo everything that was done in expandmap()
        const $bothsides = document.querySelector('.data-readouts');
        const $rightside = document.querySelector('.data-readouts-rhs');
        const $leftside = document.querySelector('.data-readouts-lhs');  // not really on the left right now cuz we moved it, we want to put it there
        const $rightunder = $rightside.querySelector('.data-readouts-rhs-lower');
        const $stats = $rightunder.querySelector('.data-readouts-rhs-demogs');
        const $download = $rightunder.querySelector('.data-readouts-rhs-download');

        $rightside.classList.add('col-md-7');
        $rightside.classList.remove('col-12');

        $bothsides.appendChild($leftside);
        $leftside.classList.add('col-md-5');
        $leftside.classList.remove('col-lg-5');
        //$leftside.classList.remove('order-first');  // keep this, appendChild() moved this to the end and we want it first (left)

        $stats.classList.add('col-lg-8');
        $stats.classList.remove('col-lg-5');

        $download.classList.add('col-lg-4');
        $download.classList.remove('col-lg-2');
        $download.classList.remove('nowrap');

        // done; tell the map that it ahs changed size
        this.map.invalidateSize();
    },
});

L.Control.expandmap = function(options) {
    return new L.Control.ExpandMap(options);
}
