# change this to your DCIM root if needed
DCIM="/run/media/salman/Salman-Data/Family/Sultan/Camera/DCIM"

# produce a report (fast-ish)
mkdir -p "$HOME/recovery_reports"
out="$HOME/recovery_reports/jpg_health_$(date +%Y%m%d_%H%M%S).txt"

find "$DCIM" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.JPG' \) -print0 \
  | while IFS= read -r -d '' f; do
      hdr=$(xxd -l 3 -p "$f" 2>/dev/null || echo "")
      if [ "$hdr" = "ffd8ff" ]; then
        echo "OK:$f"
      else
        echo "BAD:$f ($hdr)"
      fi
    done > "$out"

# summary counts
echo "Report saved to: $out"
echo "OK files:"  $(grep -c '^OK:' "$out")
echo "BAD files:" $(grep -c '^BAD:' "$out")

