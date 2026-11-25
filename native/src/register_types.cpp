#include "arms.h"
#include "battle.h"
#include "crowd.h"
#include "lane.h"
#include "painter.h"
#include "shots.h"
#include "squad.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

static void initialize(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(gunlord::Lane);
	GDREGISTER_CLASS(gunlord::Squad);
	GDREGISTER_CLASS(gunlord::Shots);
	GDREGISTER_CLASS(gunlord::Arms);
	GDREGISTER_CLASS(gunlord::Battle);
	GDREGISTER_CLASS(gunlord::Crowd);
	GDREGISTER_CLASS(gunlord::Painter);
}

static void uninitialize(ModuleInitializationLevel level) {
}

extern "C" GDExtensionBool GDE_EXPORT gunlord_init(GDExtensionInterfaceGetProcAddress get_proc_address,
		GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
	GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
	init.register_initializer(initialize);
	init.register_terminator(uninitialize);
	init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init.init();
}
