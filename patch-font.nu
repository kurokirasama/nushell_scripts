#!/usr/bin/env nu

def main [file? = "Monocraft.ttc"] {

	let nerd_font = "~/software/nerd-fonts"
	let folder = "~/Yandex.Disk/Backups/appimages" 
	let font_folder = "~/Yandex.Disk/Backups/linux"
	
	cd $folder

	cp ($font_folder | path join "Monocraft.ttc" | path expand) .

	./fontforge.AppImage -script ([$nerd_font font-patcher] | path join | path expand) ([$env.PWD $file] | path join) --complete --careful --output "Monocraft_updated.ttc" --outputdir $env.PWD

	mv -f (ls *.otf | sort-by modified | last | get name) $"($file | path parse | get stem)-nerd-fonts-patched_by_me.ttc"
  	cp -f $"($file | path parse | get stem)-nerd-fonts-patched_by_me.ttc" ($font_folder | path expand)
  	mv -f $"($file | path parse | get stem)-nerd-fonts-patched_by_me.ttc" $file

	sudo mv -f $file /usr/local/share/fonts
	fc-cache -fv;sudo fc-cache -fv
}