import pysrt
import webvtt
import os

def parse_subtitle(filepath):
    if not os.path.exists(filepath):
        return []

    ext = os.path.splitext(filepath)[1].lower()
    subs = []

    if ext == '.srt':
        try:
            srt_subs = pysrt.open(filepath)
            for sub in srt_subs:
                start_ms = sub.start.ordinal
                end_ms = sub.end.ordinal
                subs.append({
                    "start": start_ms,
                    "end": end_ms,
                    "text": sub.text
                })
        except Exception as e:
            print(f"Error parsing SRT: {e}")
    elif ext == '.vtt':
        try:
            for caption in webvtt.read(filepath):
                # webvtt timestamps are like "00:00:20.000"
                # Need to parse this to ms
                def _parse_vtt_time(time_str):
                    parts = time_str.split(':')
                    if len(parts) == 3: # HH:MM:SS.mmm
                        h, m, s = parts
                    elif len(parts) == 2: # MM:SS.mmm
                        h = 0
                        m, s = parts
                    else:
                        return 0
                    
                    s_parts = s.split('.')
                    if len(s_parts) == 2:
                        sec, ms = s_parts
                    else:
                        sec, ms = s_parts[0], 0
                    
                    return int(h) * 3600000 + int(m) * 60000 + int(sec) * 1000 + int(ms)
                
                start_ms = _parse_vtt_time(caption.start)
                end_ms = _parse_vtt_time(caption.end)
                subs.append({
                    "start": start_ms,
                    "end": end_ms,
                    "text": caption.text
                })
        except Exception as e:
            print(f"Error parsing VTT: {e}")
            
    return subs
