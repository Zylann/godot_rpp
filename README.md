Reaper file parser (.rpp) for Godot Engine 4.6+
===============================================

This is a .rpp project parser written in GDScript.

Does not support everything: a lot of data is skipped. Only what was needed or understood so far is parsed.

Note: the parser is currently written in such a way that if something yet unhandled is encountered, it will throw an error. In these cases, it should be accounted for and skipped. If its meaning is known, it may eventually be parsed more properly.

For details, see `addons/zylann.rpp/rpp_project.gd`.

![Basic viewer](screenshots/screen1.png)
