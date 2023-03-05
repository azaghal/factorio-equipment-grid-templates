Equipment Grid Templates
========================


About
-----

*Equipment Grid Templates* allows players to quickly and easily import and export equipment grid layout as blueprints. Such blueprints can be easily shared, stored, and managed using the blueprint library. It is particularly useful for setting-up the equipment grid on newly-deployed spidertrons.


Features
--------


### Create templates

Hold an empty blueprint while entity with equipment grid is opened, and an export button will be shown at bottom-left of the window. Clicking on the button while holding an empty blueprint will read information about currently configured equipment in the equipment grid, and export that information to blueprint in the form of constant combinators (see below section on format). The export button is visible _only_ when an empty, non-library blueprint is held.


### Template format

Valid inventory blueprints contain only constant combinators, with signals specifying what equipment item is placed at particular position in the equipment grid. Virtual signals are allowed as well, but they serve purely decorative purpose to denote how much space a particular piece of equipment occupies.

Each constant combinator represents a single empty space in the equipment grid configuration. Constant combinators are read from top to bottom and from left to right. Normally they will be laid-out in aligned rows, with row width and row height corresponding to dimensions of equipment grid (mapping directly to the layout in equipment grid window). Take note that the primary requirement for a template to be considered valid for a particular equipment grid is for it to have the matching number of combinators. Theoretically, you could lay-out the combinators in a single straight line, and this would still be valid from the mod perspective.

First filter slot of a combinator is used to specify equipment item placed in the grid. When encountered, the combinator that has the filter slot set is considered to be the upper-left corner of the equipment item. The next four filter slots (two through five) can be set to any virtual signal, which is useful for having a visual representation on how much space equipment is occupying in the grid. Keep in mind that these virtual signals are there merely for player's convenience when browsing through the blueprints - what really matters in terms of occupied space is the size of equipment specified in the first slot.


Known issues
------------

-   Buttons for locomotives with an equipment grid are shown in the top-left side of the opened window. Attempts to attach to the bottom result in the buttons not being visible. Most likely a bug in the game engine itself.
-   If opened window/equipment grid is particularly tall, the buttons may fail to render. Decreasing the UI scale (`Control + Numpad -`) seems to help. Most likely a bug in the game engine itself.


Contributions
-------------

Bugs and feature requests can be reported through discussion threads or through project's issue tracker. For general questions, please use discussion threads.

Pull requests for implementing new features and fixing encountered issues are always welcome.


Credits
-------

Creation of this mod has been inspired by [Quickbar Templates](https://mods.factorio.com/mod/QuickbarTemplates), mod which implements import and export of quickbar filters as blueprint templates.


License
-------

All code, documentation, and assets implemented as part of this mod are released under the terms of MIT license (see the accompanying `LICENSE` file), with the following exceptions:

-   [build.sh (factorio_development.sh)](https://code.majic.rs/majic-scripts/), by Branko Majic, under [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html).
-   `assets/thumbnail.svg`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
-   `graphics/icons/export-template-button.png`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
-   `thumbnail.png`, which is a derivative based on Factorio game assets as provided by *Wube Software Ltd*. For details, see [Factorio Terms of Service](https://www.factorio.com/terms-of-service).
