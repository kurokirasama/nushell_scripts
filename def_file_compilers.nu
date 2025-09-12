#grep for nu
#
#Examples;
#grep-nu search file.txt
#ls **/* | some_filter | grep-nu search
#open file.txt | grep-nu search
export def grep-nu [
  search:string   #search term
  entrada?:string #file or pipe
] {
  let input = $in
  let entrada = if ($entrada | is-empty) {
    if ($input | is-column name) {
      $input | get name
    } else {
      $input
    }
  } else {
    $entrada
  }

  if ('*' in $entrada) {
      grep -ihHn $search ...(glob $entrada)
  } else {
      grep -ihHn $search $entrada
  }
  | lines
  | parse "{file}:{line}:{match}"
  | str trim
  | update match {|f|
      $f.match | nu-highlight
    }
  | update file {|f|
      let info = $f.file | path parse
      $info.stem + "." + $info.extension
    }
}

export alias grp = grep-nu

#xls/ods 2 csv
export def xls2csv [
  inputFile:string
  --outputFile:string
] {
  let output = (
    if ($outputFile | is-empty) or (not $outputFile) {
      $"($inputFile | path parse | get stem).csv"
    } else {
      $outputFile
    }
  )
  libreoffice --headless --convert-to csv $inputFile
  #add in2csv
}

#my pdflatex
export def my-pdflatex [file?] {
  let tex = get-input $in $file -n
  let file_base_name = $tex | path parse | get stem
  texfot pdflatex -interaction=nonstopmode -synctex=1 $file_base_name
  bibtex $file
  sleep 0.1sec
  texfot pdflatex --shell-escape -interaction=nonstopmode -synctex=1 $file_base_name
  texfot pdflatex --shell-escape -interaction=nonstopmode -syntex=1 $file_base_name
}

#pandoc md compiler
export def my-pandoc [
  file?
  --open(-o) #open file after compilation
] {
  let file_name = get-input $in $file -n
  let file_base_name = $file_name | path parse | get stem

  pandoc --quiet $file_name -o $"($file_base_name).pdf" --pdf-engine=/usr/bin/xelatex -F mermaid-filter -F pandoc-crossref --number-sections --syntax-highlighting $env.MY_ENV_VARS.pandoc_theme

  if $open {
    openf $"($file_base_name).pdf"
  }
}

#generate an unique md from all files in current directory recursively
export def generate-md-from-dir [output_file = "output.md"] {
  # Initialize output file
  "" | save $output_file

  ls **/*
  | where type == file
  | where name not-like "png|jpg"
  | where name != $output_file
  | each { |it|
    let filepath = $it.name
    let file_content = open $filepath

    # Create the section header
    let section_header = $"\n# ($filepath)\n"
    $section_header | save -a $output_file

    # Create the code block
    let code_block_start = "\n```\n"
    $code_block_start | save -a $output_file

    $file_content | save -a $output_file

    let code_block_end = "\n```\n"
    $code_block_end | save -a $output_file

    print $"Generated section for ($filepath)"
  }
  print $"All file contents copied to ($output_file)"
}
