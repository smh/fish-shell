function help --description 'Show help for the fish shell'
    set -l options 'h/help'
    argparse -n help --max-args=1 $options -- $argv
    or return

    if set -q _flag_help
        __fish_print_help help
        return 0
    end

    set -l fish_help_item $argv[1]
    set -l help_topics syntax completion editor job-control todo bugs history killring help
    set -a help_topics color prompt title variables builtin-overview changes expand
    set -a help_topics expand-variable expand-home expand-brace expand-wildcard
    set -a help_topics expand-command-substitution expand-process

    #
    # Find a suitable browser for viewing the help pages. This is needed
    # by the help function defined below.
    #
    set -l fish_browser
    set -l graphical_browsers htmlview x-www-browser firefox galeon mozilla konqueror epiphany opera netscape rekonq google-chrome chromium-browser

    if set -q fish_help_browser[1]
        # User has set a fish-specific help browser. This overrides the
        # browser that may be defined by $BROWSER. The fish_help_browser
        # variable may be an array containing a browser name plus options.
        set fish_browser $fish_help_browser
    else
        set -l text_browsers htmlview www-browser links elinks lynx w3m

        if set -q BROWSER
            # User has manually set a preferred browser, so we respect that
            set fish_browser $BROWSER
        else
            # Check for a text-based browser.
            for i in $text_browsers
                if type -q -f $i
                    set fish_browser $i
                    break
                end
            end

            # If we are in a graphical environment, check if there is a graphical
            # browser to use instead.
            if test "$DISPLAY" -a \( "$XAUTHORITY" = "$HOME/.Xauthority" -o "$XAUTHORITY" = "" \)
                for i in $graphical_browsers
                    if type -q -f $i
                        set fish_browser $i
                        break
                    end
                end
            end

            # If the OS appears to be Windows (graphical), try to use cygstart
            if type -q cygstart
                set fish_browser cygstart
            # If xdg-open is available, just use that
            # but only if an X session is running
            else if type -q xdg-open; and set -q -x DISPLAY
                set fish_browser xdg-open
            end

            # On OS X, we go through osascript by default
            if test (uname) = Darwin
                if type -q osascript
                    set fish_browser osascript
                end
            end
        end
    end

    if not set -q fish_browser[1]
        printf (_ '%s: Could not find a web browser.\n') help
        printf (_ 'Please set the variable $BROWSER or fish_help_browser and try again.\n\n')
        return 1
    end

    # In Cygwin, start the user-specified browser using cygstart
    if type -q cygstart
        if test $fish_browser != "cygstart"
            # Escaped quotes are necessary to work with spaces in the path
            # when the command is finally eval'd.
            set fish_browser cygstart \"$fish_browser\"
        end
    end

    switch "$fish_help_item"
        case "."
            set fish_help_page "commands.html\#source"
        case globbing
            set fish_help_page "index.html\#expand"
        case (__fish_print_commands)
            set fish_help_page "commands.html\#$fish_help_item"
        case $help_topics
            set fish_help_page "index.html\#$fish_help_item"
        case 'tut_*'
            set fish_help_page "tutorial.html\#$fish_help_item"
        case tutorial
            set fish_help_page "tutorial.html"
        case "*"
            # If $fish_help_item is empty, this will fail,
            # and $fish_help_page will end up as index.html
            if type -q -f "$fish_help_item"
                # Prefer to use fish's man pages, to avoid
                # the annoying useless "builtin" man page bash
                # installs on OS X
                set -l man_arg "$__fish_datadir/man/man1/$fish_help_item.1"
                if test -f "$man_arg"
                    man $man_arg
                    return
                end
            end
            set fish_help_page "index.html"
    end

    set -l page_url
    if test -f $__fish_help_dir/index.html
        # Help is installed, use it
        set page_url file://$__fish_help_dir/$fish_help_page

        # In Cygwin, we need to convert the base help dir to a Windows path before converting it to a file URL
        if type -q cygpath
            set page_url file://(cygpath -m $__fish_help_dir)/$fish_help_page
        end
    else
        # Go to the web. Only include one dot in the version string
        set -l version_string (echo $version| cut -d . -f 1,2)
        set page_url https://fishshell.com/docs/$version_string/$fish_help_page
    end

    # OS X /usr/bin/open swallows fragments (anchors), so use osascript
    # Eval is just a cheesy way of removing the hash escaping
    if test "$fish_browser" = osascript
        set -l opencmd 'open location "'(eval echo $page_url)'"'
        osascript -e 'try' -e $opencmd -e 'on error' -e $opencmd -e 'end try'
        return
    end


    # If browser is known to be graphical, put into background
    if contains -- $fish_browser[1] $graphical_browsers
        switch $fish_browser[1]
            case 'htmlview' 'x-www-browser'
                printf (_ 'help: Help is being displayed in your default browser.\n')
            case '*'
                printf (_ 'help: Help is being displayed in %s.\n') $fish_browser[1]
        end
        eval "$fish_browser $page_url &"
    else
        # Work around lynx bug where <div class="contents"> always has the same formatting as links (unreadable)
        # by using a custom style sheet. See https://github.com/fish-shell/fish-shell/issues/4170
        set -l local_file 0
        if eval $fish_browser --version 2>/dev/null | string match -qr Lynx
            set fish_browser $fish_browser -lss={$__fish_datadir}/lynx.lss
        end
        eval $fish_browser $page_url
    end
end
