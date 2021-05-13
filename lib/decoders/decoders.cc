#include "globals.h"
#include "flags.h"
#include "fluxmap.h"
#include "decoders/decoders.h"
#include "encoders/encoders.h"
#include "arch/brother/brother.h"
#include "arch/ibm/ibm.h"
#include "decoders/fluxmapreader.h"
#include "record.h"
#include "protocol.h"
#include "decoders/rawbits.h"
#include "track.h"
#include "sector.h"
#include "lib/decoders/decoders.pb.h"
#include "fmt/format.h"
#include <numeric>

std::unique_ptr<AbstractDecoder> AbstractDecoder::create(const Decoder& config)
{
	switch (config.format_case())
	{
		case Decoder::kIbm:
			return std::unique_ptr<AbstractDecoder>(new IbmDecoder(config.ibm()));

		case Decoder::kBrother:
			return std::unique_ptr<AbstractDecoder>(new BrotherDecoder(config.brother()));

		default:
			Error() << "no input disk format specified";
	}

	return std::unique_ptr<AbstractDecoder>();
}

void AbstractDecoder::decodeToSectors(Track& track)
{
    Sector sector;
    sector.physicalSide = track.physicalSide;
    sector.physicalTrack = track.physicalTrack;
    FluxmapReader fmr(*track.fluxmap);

    _track = &track;
    _sector = &sector;
    _fmr = &fmr;

    beginTrack();
    for (;;)
    {
        Fluxmap::Position recordStart = fmr.tell();
        sector.clock = 0;
        sector.status = Sector::MISSING;
        sector.data.clear();
        sector.logicalSector = sector.logicalSide = sector.logicalTrack = 0;
        RecordType r = advanceToNextRecord();
        if (fmr.eof() || !sector.clock)
            return;
        if ((r == UNKNOWN_RECORD) || (r == DATA_RECORD))
        {
            fmr.findEvent(F_BIT_PULSE);
            continue;
        }

        /* Read the sector record. */

        sector.position = recordStart = fmr.tell();
        decodeSectorRecord();
        Fluxmap::Position recordEnd = fmr.tell();
        pushRecord(recordStart, recordEnd);
        if (sector.status == Sector::DATA_MISSING)
        {
            /* The data is in a separate record. */

            sector.headerStartTime = recordStart.ns();
            sector.headerEndTime = recordEnd.ns();
			for (;;)
			{
				r = advanceToNextRecord();
				if (r != UNKNOWN_RECORD)
					break;
				if (fmr.findEvent(F_BIT_PULSE) == 0)
                    break;
			}
            recordStart = fmr.tell();
            if (r == DATA_RECORD)
                decodeDataRecord();
            recordEnd = fmr.tell();
            pushRecord(recordStart, recordEnd);
        }
        sector.dataStartTime = recordStart.ns();
        sector.dataEndTime = recordEnd.ns();

        if (sector.status != Sector::MISSING)
            track.sectors.push_back(sector);
    }
}

void AbstractDecoder::pushRecord(const Fluxmap::Position& start, const Fluxmap::Position& end)
{
    Fluxmap::Position here = _fmr->tell();

    RawRecord record;
    record.physicalSide = _track->physicalSide;
    record.physicalTrack = _track->physicalTrack;
    record.clock = _sector->clock;
    record.position = start;

    _fmr->seek(start);
    record.data = toBytes(_fmr->readRawBits(end, _sector->clock));
    _track->rawrecords.push_back(record);
    _fmr->seek(here);
}

std::set<unsigned> AbstractDecoder::requiredSectors(Track& track) const
{
	static std::set<unsigned> empty;
	return empty;
}

