function fastfetch --wraps fastfetch --description 'fastfetch con -nl para ocultar el logo'
    set -l args
    for a in $argv
        if test "$a" = -nl
            set args $args -l none
        else
            set args $args $a
        end
    end
    command fastfetch $args
end
