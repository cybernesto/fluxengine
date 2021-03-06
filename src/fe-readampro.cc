#include "globals.h"
#include "flags.h"
#include "reader.h"
#include "fluxmap.h"
#include "decoders/decoders.h"
#include "sector.h"
#include "sectorset.h"
#include "record.h"
#include "ibm/ibm.h"
#include "fmt/format.h"

static FlagGroup flags { &readerFlags };

static IntFlag sectorIdBase(
	{ "--sector-id-base" },
	"Sector ID of the first sector.",
	17);

int mainReadAmpro(int argc, const char* argv[])
{
	setReaderDefaultSource(":t=0-79:s=0");
	setReaderDefaultOutput("ampro.adf");
    setReaderRevolutions(2);
    flags.parseFlags(argc, argv);

	IbmDecoder decoder(sectorIdBase);
	readDiskCommand(decoder);
    return 0;
}

