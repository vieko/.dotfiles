import os
import glob

def list_categories():
    desktop_files = glob.glob('/usr/share/applications/*.desktop')
    categories = set()

    for file in desktop_files:
        with open(file, 'r') as f:
            for line in f:
                if line.startswith('Categories='):
                    cats = line.strip().split('=')[1].split(';')
                    categories.update(cats)

    return sorted(list(categories))

if __name__ == "__main__":
    print("Categories found in .desktop files:")
    for category in list_categories():
        if category:  # Avoid empty category strings
            print(f"- {category}")
