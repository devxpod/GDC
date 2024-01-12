# use these to change the window / tab title. echo -e "$title_start THE_TITLE $title_end"
title_start='\e]0;'
title_end='\a'

txtblk='\e[0;30m' # Black - Regular
txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;33m' # Yellow
txtblu='\e[0;34m' # Blue
txtpur='\e[0;35m' # Purple
txtcyn='\e[0;36m' # Cyan
txtwht='\e[0;37m' # White

bldblk='\e[1;30m' # Black - Bold
bldred='\e[1;31m' # Red
bldgrn='\e[1;32m' # Green
bldylw='\e[1;33m' # Yellow
bldblu='\e[1;34m' # Blue
bldpur='\e[1;35m' # Purple
bldcyn='\e[1;36m' # Cyan
bldwht='\e[1;37m' # White

unkblk='\e[4;30m' # Black - Underline
undred='\e[4;31m' # Red
undgrn='\e[4;32m' # Green
undylw='\e[4;33m' # Yellow
undblu='\e[4;34m' # Blue
undpur='\e[4;35m' # Purple
undcyn='\e[4;36m' # Cyan
undwht='\e[4;37m' # White

bakblk='\e[40m'   # Black - Background
bakred='\e[41m'   # Red
bakgrn='\e[42m'   # Green
bakylw='\e[43m'   # Yellow
bakblu='\e[44m'   # Blue
bakpur='\e[45m'   # Purple
bakcyn='\e[46m'   # Cyan
bakwht='\e[47m'   # White
txtrst='\e[0m'    # Text Reset

# p_* vars are for use in shell prompts. The extra escape brackets are are so the shell knows not to include the code in the length of the line.
p_txtblk="\[$txtblk\]" # Black - Regular
p_txtred="\[$txtred\]" # Red
p_txtgrn="\[$txtgrn\]" # Green
p_txtylw="\[$txtylw\]" # Yellow
p_txtblu="\[$txtblu\]" # Blue
p_txtpur="\[$txtpur\]" # Purple
p_txtcyn="\[$txtcyn\]" # Cyan
p_txtwht="\[$txtwht\]" # White

p_bldblk="\[$bldblk\]" # Black - Bold
p_bldred="\[$bldred\]" # Red
p_bldgrn="\[$bldgrn\]" # Green
p_bldylw="\[$bldylw\]" # Yellow
p_bldblu="\[$bldblu\]" # Blue
p_bldpur="\[$bldpur\]" # Purple
p_bldcyn="\[$bldcyn\]" # Cyan
p_bldwht="\[$bldwht\]" # White

p_unkblk="\[$unkblk\]" # Black - Underline
p_undred="\[$undred\]" # Red
p_undgrn="\[$undgrn\]" # Green
p_undylw="\[$undylw\]" # Yellow
p_undblu="\[$undblu\]" # Blue
p_undpur="\[$undpur\]" # Purple
p_undcyn="\[$undcyn\]" # Cyan
p_undwht="\[$undwht\]" # White

p_bakblk="\[$bakblk\]" # Black - Background
p_bakred="\[$bakred\]" # Red
p_bakgrn="\[$bakgrn\]" # Green
p_bakylw="\[$bakylw\]" # Yellow
p_bakblu="\[$bakblu\]" # Blue
p_bakpur="\[$bakpur\]" # Purple
p_bakcyn="\[$bakcyn\]" # Cyan
p_bakwht="\[$bakwht\]" # White
p_txtrst="\[$txtrst\]" # Text Reset

