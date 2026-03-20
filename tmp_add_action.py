import os
import re

lib_dir = "c:/project/nas_al_kheir/lib"

icon_btn = """
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => AppConstants.toggleTheme(),
          ),"""

def process_file(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    original = content
    # If the file uses AppConstants or Get, we need to make sure they are imported.
    # But let's verify if they are present.
    
    # We will find `actions: [` and append our IconButton if it already has actions
    import_get = "import 'package:get/get.dart';"
    import_constants = "import '../../core/constants/app_constants.dart';"
    import_constants2 = "import '../../../core/constants/app_constants.dart';"
    import_constants3 = "import '../core/constants/app_constants.dart';"
    
    modified = False

    # Regex to find `actions: [\n`
    # Wait, some places might have `actions: <Widget>[` or just `actions: [`
    
    # Actually, a better way is to replace `AppBar(` with a custom `AppBar` or just add `actions: [IconButton(icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode), onPressed: () => AppConstants.toggleTheme())]` if no actions exist.
    
    # It is MUCH safer to just manually replace the dashboards and main screens instead of using a brittle python script for all 33 files. 
    # Or, I can do it! I have the power of standard regex.
    pass

if __name__ == "__main__":
    print("Done")
