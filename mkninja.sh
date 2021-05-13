#!/bin/sh
set -e

cat <<EOF
rule cxx
    command = $CXX $CFLAGS \$flags -I. -c -o \$out \$in -MMD -MF \$out.d
    description = CXX \$in
    depfile = \$out.d
    deps = gcc
    
rule proto
    command = $PROTOC \$flags \$in && (echo \$in > \$def)
    description = PROTO \$in

rule protoencode
    command = (echo '#include <string>' && echo 'static const unsigned char data[] = {' && ($PROTOC \$flags --encode=\$messagetype \$\$(cat \$def)< \$in | $XXD -i) && echo '}; extern std::string \$name(); std::string \$name() { return std::string((const char*)data, sizeof(data)); }') > \$out
    description = PROTOENCODE \$in

rule binencode
    command = xxd -i \$in > \$out
    description = XXD \$in

rule library
    command = $AR \$out \$in
    description = AR \$in

rule link
    command = $CXX $LDFLAGS -o \$out \$in \$flags $LIBS
    description = LINK \$in

rule test
    command = \$in && touch \$out
    description = TEST \$in

rule strip
    command = cp -f \$in \$out && $STRIP \$out
    description = STRIP \$in
EOF

buildlibrary() {
    local lib
    lib=$1
    shift

    local flags
    flags=
    while true; do
        case $1 in
            -*)
                flags="$flags $1"
                shift
                ;;

            *)
                break
        esac
    done

    local oobjs
    local dobjs
    oobjs=
    dobjs=
    for src in "$@"; do
        local obj
        obj="$OBJDIR/opt/${src%%.c*}.o"
        oobjs="$oobjs $obj"

        echo build $obj : cxx $src
        echo "    flags=$flags $COPTFLAGS"

        obj="$OBJDIR/dbg/${src%%.c*}.o"
        dobjs="$dobjs $obj"

        echo build $obj : cxx $src
        echo "    flags=$flags $CDBGFLAGS"
    done

    echo build $OBJDIR/opt/$lib : library $oobjs
    echo build $OBJDIR/dbg/$lib : library $dobjs
}

buildproto() {
    local lib
    lib=$1
    shift

    local def
    def=$OBJDIR/proto/${lib%%.a}.def

    local flags
    flags=
    while true; do
        case $1 in
            -*)
                flags="$flags $1"
                shift
                ;;

            *)
                break
        esac
    done

    local cfiles
    cfiles=
    for src in "$@"; do
        local cfile
        cfile="$OBJDIR/proto/${src%%.proto}.pb.cc"
        cfiles="$cfiles $cfile"
    done

    echo build $cfiles $def : proto $@
    echo "    flags=$flags --cpp_out=$OBJDIR/proto"
    echo "    def=$def"

    buildlibrary $lib -I$OBJDIR/proto $cfiles
}

buildencodedproto() {
    local def
    local message
    local name
    local input
    local output
    def=$1
    message=$2
    name=$3
    input=$4
    output=$5

    echo "build $output : protoencode $input | $def"
    echo "    name=$name"
    echo "    def=$def"
    echo "    messagetype=$message"
}

buildprogram() {
    local prog
    prog=$1
    shift

    local flags
    flags=
    while true; do
        case $1 in
            -*)
                flags="$flags $1"
                shift
                ;;

            *)
                break
        esac
    done

    local oobjs
    local dobjs
    oobjs=
    dobjs=
    for src in "$@"; do
        oobjs="$oobjs $OBJDIR/opt/$src"
        dobjs="$dobjs $OBJDIR/dbg/$src"
    done

    echo build $prog-debug$EXTENSION : link $dobjs
    echo "    flags=$flags $LDDBGFLAGS"

    echo build $prog$EXTENSION : link $oobjs
    echo "    flags=$flags $LDOPTFLAGS"

}

buildsimpleprogram() {
    local prog
    prog=$1
    shift

    local flags
    flags=
    while true; do
        case $1 in
            -*)
                flags="$flags $1"
                shift
                ;;

            *)
                break
        esac
    done

    local src
    src=$1
    shift

    buildlibrary lib$prog.a $flags $src
    buildprogram $prog lib$prog.a "$@"
}

runtest() {
    local prog
    prog=$1
    shift

    buildlibrary lib$prog.a \
        -Idep/snowhouse/include \
        "$@"

    buildprogram $OBJDIR/$prog \
        lib$prog.a \
        libbackend.a \
        libproto.a \
        libtestproto.a \
        libagg.a \
        libfmt.a

    echo build $OBJDIR/$prog.stamp : test $OBJDIR/$prog-debug$EXTENSION
}

buildlibrary libagg.a \
    -Idep/agg/include \
    dep/stb/stb_image_write.c \
    dep/agg/src/*.cpp

buildlibrary libfmt.a \
    dep/fmt/format.cc \
    dep/fmt/posix.cc \

buildproto libproto.a \
    arch/brother/brother.proto \
    arch/ibm/ibm.proto \
    lib/config.proto \
    lib/encoders/encoders.proto \
    lib/decoders/decoders.proto \
    lib/imagereader/img.proto \
    lib/fluxsource/fluxsource.proto \
    lib/common.proto \

buildlibrary libbackend.a \
    -I$OBJDIR/proto \
    lib/imagereader/diskcopyimagereader.cc \
    lib/imagereader/imagereader.cc \
    lib/imagereader/imgimagereader.cc \
    lib/imagereader/jv3imagereader.cc \
    lib/imagereader/imdimagereader.cc \
    lib/imagewriter/d64imagewriter.cc \
    lib/imagewriter/diskcopyimagewriter.cc \
    lib/imagewriter/imagewriter.cc \
    lib/imagewriter/imgimagewriter.cc \
    lib/imagewriter/ldbsimagewriter.cc \
    arch/aeslanier/decoder.cc \
    arch/amiga/decoder.cc \
    arch/amiga/encoder.cc \
    arch/amiga/amiga.cc \
    arch/apple2/decoder.cc \
    arch/brother/decoder.cc \
    arch/brother/encoder.cc \
    arch/c64/decoder.cc \
    arch/f85/decoder.cc \
    arch/fb100/decoder.cc \
    arch/ibm/decoder.cc \
    arch/ibm/encoder.cc \
    arch/macintosh/decoder.cc \
    arch/macintosh/encoder.cc \
    arch/micropolis/decoder.cc \
    arch/mx/decoder.cc \
    arch/tids990/decoder.cc \
    arch/tids990/encoder.cc \
    arch/victor9k/decoder.cc \
    arch/zilogmcz/decoder.cc \
    lib/bytes.cc \
    lib/crc.cc \
    lib/dataspec.cc \
    lib/decoders/decoders.cc \
    lib/decoders/fluxmapreader.cc \
    lib/decoders/fmmfm.cc \
    lib/encoders/encoders.cc \
	lib/flaggroups/fluxsourcesink.cc \
    lib/flags.cc \
    lib/fluxmap.cc \
    lib/fluxsink/fluxsink.cc \
    lib/fluxsink/hardwarefluxsink.cc \
    lib/fluxsink/sqlitefluxsink.cc \
    lib/fluxsource/fluxsource.cc \
    lib/fluxsource/hardwarefluxsource.cc \
    lib/fluxsource/testpatternfluxsource.cc \
    lib/fluxsource/kryoflux.cc \
    lib/fluxsource/sqlitefluxsource.cc \
    lib/fluxsource/streamfluxsource.cc \
    lib/usb/usb.cc \
    lib/usb/fluxengineusb.cc \
    lib/usb/greaseweazle.cc \
    lib/usb/greaseweazleusb.cc \
    lib/csvreader.cc \
    lib/globals.cc \
    lib/hexdump.cc \
    lib/ldbs.cc \
    lib/proto.cc \
    lib/reader.cc \
    lib/sector.cc \
    lib/sectorset.cc \
    lib/sql.cc \
    lib/utils.cc \
    lib/writer.cc \

for pb in \
    brother \
    ibm \
; do
    buildencodedproto $OBJDIR/proto/libproto.def Config \
        readables_${pb}_pb src/readables/$pb.textpb $OBJDIR/proto/src/readables/$pb.cc
done

for pb in \
    brother240 \
    ibm1440 \
; do
    buildencodedproto $OBJDIR/proto/libproto.def Config \
        writables_${pb}_pb src/writables/$pb.textpb $OBJDIR/proto/src/writables/$pb.cc
done

buildlibrary libfrontend.a \
    -I$OBJDIR/proto \
    src/fe-analysedriveresponse.cc \
    src/fe-analyselayout.cc \
    src/fe-cwftoflux.cc \
    src/fe-erase.cc \
    src/fe-fluxtoau.cc \
    src/fe-fluxtoscp.cc \
    src/fe-fluxtovcd.cc \
    src/fe-image.cc \
    src/fe-inspect.cc \
    src/fe-read.cc \
    src/fe-rpm.cc \
    src/fe-scptoflux.cc \
    src/fe-seek.cc \
    src/fe-testbandwidth.cc \
    src/fe-testvoltages.cc \
    src/fe-upgradefluxfile.cc \
    src/fe-write.cc \
    src/fe-writeflux.cc \
    src/fluxengine.cc \
    $OBJDIR/proto/src/readables/brother.cc \
    $OBJDIR/proto/src/readables/ibm.cc \
    $OBJDIR/proto/src/writables/brother240.cc \
    $OBJDIR/proto/src/writables/ibm1440.cc \

#    src/fe-readadfs.cc \
#    src/fe-readaeslanier.cc \
#    src/fe-readamiga.cc \
#    src/fe-readampro.cc \
#    src/fe-readapple2.cc \
#    src/fe-readatarist.cc \
#    src/fe-readbrother.cc \
#    src/fe-readc64.cc \
#    src/fe-readdfs.cc \
#    src/fe-readf85.cc \
#    src/fe-readfb100.cc \
#    src/fe-readibm.cc \
#    src/fe-readmac.cc \
#    src/fe-readmicropolis.cc \
#    src/fe-readmx.cc \
#    src/fe-readtids990.cc \
#    src/fe-readvictor9k.cc \
#    src/fe-readzilogmcz.cc \
#    src/fe-writeamiga.cc \
#    src/fe-writebrother.cc \
#    src/fe-writeibm.cc \
#    src/fe-writemac.cc \
#    src/fe-writetids990.cc \

buildprogram fluxengine \
    libfrontend.a \
    libbackend.a \
    libproto.a \
    libfmt.a \
    libagg.a \

buildlibrary libemu.a \
    dep/emu/fnmatch.c

buildsimpleprogram brother120tool \
    -Idep/emu \
    tools/brother120tool.cc \
    libbackend.a \
    libemu.a \
    libfmt.a \

buildsimpleprogram brother240tool \
    -Idep/emu \
    tools/brother240tool.cc \
    libbackend.a \
    libemu.a \
    libfmt.a \

buildproto libtestproto.a \
    tests/testproto.proto \

buildencodedproto $OBJDIR/proto/libtestproto.def TestProto testproto_pb tests/testproto.textpb $OBJDIR/proto/tests/testproto.cc

runtest agg-test            tests/agg.cc
runtest amiga-test          tests/amiga.cc
runtest bitaccumulator-test tests/bitaccumulator.cc
runtest bytes-test          tests/bytes.cc
runtest compression-test    tests/compression.cc
runtest csvreader-test      tests/csvreader.cc
runtest dataspec-test       tests/dataspec.cc
runtest flags-test          tests/flags.cc
runtest fluxpattern-test    tests/fluxpattern.cc
runtest fmmfm-test          tests/fmmfm.cc
runtest greaseweazle-test   tests/greaseweazle.cc
runtest kryoflux-test       tests/kryoflux.cc
runtest ldbs-test           tests/ldbs.cc
runtest proto-test          -I$OBJDIR/proto tests/proto.cc $OBJDIR/proto/tests/testproto.cc

# vim: sw=4 ts=4 et

