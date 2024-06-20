#!/usr/bin/env nu

def main [file? = "Monocraft.otf"] {

	let nerd_font = "~/software/nerd-fonts"
	let folder = "~/Yandex.Disk/Backups/appimages" 
	let font_folder = "~/Yandex.Disk/Backups/linux"
	
	cd $folder

	cp ([$font_folder Monocraft.otf] | path join) .

	./fontforge.AppImage -script ([$nerd_font font-patcher] | path join | path expand) ([$env.PWD $file] | path join) --complete --careful --output "Monocraft_updated.otf" --outputdir $env.PWD

	mv -f (ls *.otf | sort-by modified | last | get name) $"($file)-nerd-fonts-patched.otf"
  	cp -f $"($file)-nerd-fonts-patched.otf" $font_folder
  	mv -f $"($file)-nerd-fonts-patched.otf" $file

	sudo mv -f $file /usr/local/share/fonts
	fc-cache -fv;sudo fc-cache -fv
}