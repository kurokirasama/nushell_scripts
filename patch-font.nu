#!/usr/bin/env nu

def update_repo [] {
	let nerd_font = ("~/software/nerd-fonts" | path expand)
	if not ($nerd_font | path exists) or not (($nerd_font | path join ".git") | path exists) {
		print "Cloning sparse nerd-fonts repository (shallow)..."
		mkdir ("~/software" | path expand)
		cd ("~/software" | path expand)
		try { rm -rf nerd-fonts } catch {}
		^git clone --depth 1 --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git nerd-fonts
		cd nerd-fonts
		^git sparse-checkout init --no-cone
		^git sparse-checkout set font-patcher "src/glyphs/*" "bin/scripts/*" glyphnames.json package.json 10-nerd-font-symbols.conf
	} else {
		print "Pulling latest changes from nerd-fonts origin..."
		cd $nerd_font
		try { ^git pull origin master } catch {}
	}
}

def clean_repo [] {
	let repo = ("~/software/nerd-fonts" | path expand)
	if ($repo | path exists) {
		cd $repo
		try { rm -rf patched-fonts } catch {}
		try { rm -f *.zip *.ttc *.ttf *.otf } catch {}
		try { ^git clean -fd } catch {}
		cd -
	}
}

def main [file? = "Monocraft.ttc", --no-update(-n)] {
	if not $no_update {
		update_repo
	}

	let nerd_font = "~/software/nerd-fonts"
	let folder = "~/Yandex.Disk/Backups/appimages" 
	let font_folder = "~/Yandex.Disk/Backups/linux"
	
	cd $folder

	let src_file = ($font_folder | path join $file | path expand)
	if ($src_file | path exists) {
		cp -f $src_file .
	}

	let patcher = ([$nerd_font font-patcher] | path join | path expand)
	let target = ([$env.PWD $file] | path join)
	with-env { PYTHONIOENCODING: "utf-8", LANG: "en_US.UTF-8", LC_ALL: "en_US.UTF-8" } {
		./fontforge.AppImage -script $patcher $target --complete --careful --outputdir $env.PWD
	}

	let latest_ttc = (try { 
		ls *.ttc | where name !~ "-nerd-fonts-patched_by_me" and name != $target | sort-by modified | last | get name 
	} catch { "" })
	if ($latest_ttc | is-not-empty) {
		let patched_name = $"($file | path parse | get stem)-nerd-fonts-patched_by_me.ttc"
		mv -f $latest_ttc $patched_name
		cp -f $patched_name ($font_folder | path expand)

		try { sudo cp -f $patched_name /usr/local/share/fonts/Monocraft.ttc } catch {}
		try {
			mkdir ("~/.local/share/fonts" | path expand)
			cp -f $patched_name ("~/.local/share/fonts/Monocraft.ttc" | path expand)
		} catch {}
		fc-cache -fv; try { sudo fc-cache -fv } catch {}
	}
	try { rm -f $target } catch {}

	clean_repo
	print "Font patching complete."
}