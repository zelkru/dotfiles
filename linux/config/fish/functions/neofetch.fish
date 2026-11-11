function neofetch --wraps neofetch --description 'neofetch con -nl para ocultar el logo'
    set -l args
    for a in $argv
        if test "$a" = -nl
            set args $args --off
        else
            set args $args $a
        end
    end
    command neofetch $args
end
