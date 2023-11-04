#copy private nushell script repo to public one and commit
export def copy-scripts-and-commit [] {
  let files = (
    ls $env.MY_ENV_VARS.nu_scripts 
    | find -v private & signature & env_vars & ntfy
    | append (ls $env.MY_ENV_VARS.linux_backup | find append)
    | append (ls $env.MY_ENV_VARS.credentials | find -v .asc)
  )

  $files | cp-pipe -u $env.MY_ENV_VARS.nu_scripts_public

  cd $env.MY_ENV_VARS.nu_scripts_public
  ai git-push -g
}