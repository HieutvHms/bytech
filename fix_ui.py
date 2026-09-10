import re

with open('lib/new_screen/connect_screen.dart', 'r') as f:
    content = f.read()

# Replace SizedBox(height: MediaQuery...) with just the child and add shrinkWrap
pattern = r'SizedBox\(\s*height:\s*MediaQuery\.of\(context\)\.size\.height\s*\*\s*0\.5,\s*child:\s*(ListView\.separated\()'
replacement = r'\1\n                                  shrinkWrap: true,\n                                  physics: const NeverScrollableScrollPhysics(),'

new_content = re.sub(pattern, replacement, content)

# Now we have trailing `),` from the removed SizedBoxes. 
# It's tricky to remove them with regex without breaking something else.
# Let's do it manually.

with open('lib/new_screen/connect_screen.dart', 'w') as f:
    f.write(new_content)
