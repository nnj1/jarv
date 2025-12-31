import bpy
import os
import sys

# Clear existing objects in the scene
bpy.ops.wm.read_factory_settings(use_empty=True)

# Get input/output from command line arguments
input_path = sys.argv[-2]
output_path = sys.argv[-1]

# Import FBX
bpy.ops.import_scene.fbx(filepath=input_path)

# Save as .blend
bpy.ops.wm.save_as_mainfile(filepath=output_path)
