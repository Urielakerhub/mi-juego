#!/usr/bin/env python
# Compila la extensión C++ (GDExtension). Requiere godot-cpp junto a este archivo:
#   git clone --branch godot-4.3-stable https://github.com/godotengine/godot-cpp.git
#   pip install scons
#   scons platform=linux   (o platform=windows)  target=template_release
env = SConscript("godot-cpp/SConstruct")
env.Append(CPPPATH=["gdextension"])
sources = Glob("gdextension/*.cpp")
library = env.SharedLibrary(
    "project/bin/libeclipse.{}.{}{}".format(env["platform"], env["arch"], env["SHLIBSUFFIX"]),
    source=sources,
)
Default(library)
