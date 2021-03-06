#ifndef TIDS990_H
#define TIDS990_H

#define TIDS990_PAYLOAD_SIZE       288 /* bytes */
#define TIDS990_SECTOR_RECORD_SIZE 10 /* bytes */
#define TIDS990_DATA_RECORD_SIZE   (TIDS990_PAYLOAD_SIZE + 4) /* bytes */

class Sector;
class SectorSet;
class Fluxmap;
class Track;

class TiDs990Decoder : public AbstractDecoder
{
public:
    virtual ~TiDs990Decoder() {}

    RecordType advanceToNextRecord();
    void decodeSectorRecord();
	void decodeDataRecord();
};

class TiDs990Encoder : public AbstractEncoder
{
public:
	virtual ~TiDs990Encoder() {}

private:
	void writeRawBits(uint32_t data, int width);
	void writeBytes(const Bytes& bytes);
	void writeBytes(int count, uint8_t value);
	void writeSync();

public:
    std::unique_ptr<Fluxmap> encode(int physicalTrack, int physicalSide, const SectorSet& allSectors);

private:
	std::vector<bool> _bits;
	unsigned _cursor;
	bool _lastBit;
};

extern FlagGroup tids990EncoderFlags;

#endif


