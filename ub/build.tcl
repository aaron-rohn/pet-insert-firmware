
proc build { ws_path src_path inc_path } {
    puts "\n\nBuilding: $ws_path\n\n"

    cd $ws_path
    setws -switch $ws_path

    set hdf_file [glob -nocomplain *.hdf]
    if { [llength $hdf_file] != 1 } {
        puts "Unable to find .hdf in workspace"
        return
    }

    foreach proj [getprojects] {
        deleteprojects -name $proj
    }

    createhw -name hw0 -hwspec $hdf_file
    createbsp -name bsp0 -proc microblaze_0 -hwproject hw0 -os standalone
    createapp -name ub0 -hwproject hw0 -bsp bsp0 -proc microblaze_0 -os standalone -lang C -app {Empty Application}

    foreach src $src_path {
        importsources -name ub0 -path $src
    }

    configapp -app ub0 compiler-optimization {Optimize more (-O2)}
    #configapp -app ub0 compiler-misc {-g}

    set inc_base [file join $ws_path bsp0/microblaze_0/include]
    foreach inc [list $inc_path $inc_base] {
        configapp -app ub0 include-path $inc
    }

    projects -build
}

#build /home/aaron/insert/ub/sync \
#      /home/aaron/insert/src/ub/sync_src \
#      /home/aaron/insert/src/ub/include

#build /home/aaron/insert/ub/backend \
#      {/home/aaron/insert/src/ub/backend_src /home/aaron/insert/src/ub/common} \
#      /home/aaron/insert/src/ub/include

build /home/aaron/insert/ub/frontend \
      {/home/aaron/insert/src/ub/frontend_src /home/aaron/insert/src/ub/common} \
      /home/aaron/insert/src/ub/include
