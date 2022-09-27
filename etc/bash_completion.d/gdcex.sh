_get_containers()
{
        local cur prev opts
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        opts=$(docker network inspect "$DEVNET_NAME" | jq -r '.[0].Containers[].Name' | grep -v 'arn_aws' | grep -v $PROJECT_NAME"-dev-1" | sort)

#echo cur=$cur
#echo prev=$prev
#echo opts=$opts


        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
}
complete -F _get_containers gdcex.sh
