"""Replay fixed inputs continuously through 2-2, 2-3 and 2-4, without state patches."""
import run_gameplay_route


def validate_campaign(rows, movie):
    reasons = []
    if (movie.get('world'), movie.get('level')) != (2, 2):
        reasons.append('campaign must start at 2-2')
    if len(rows) != movie['frames'] + 1 or [r['frame'] for r in rows] != list(range(len(rows))):
        reasons.append('missing, extra or non-contiguous frames')
    stages = []
    for row in rows:
        stage = (row['world'], row['level'])
        if not stages or stages[-1] != stage:
            stages.append(stage)
    if stages != [(2, 2), (2, 3), (2, 4), (3, 1)]:
        reasons.append('incorrect stage sequence')
    deaths = [r['frame'] for r in rows if r['dead'] or r['state'] in ('deathReload', 'gameOver')]
    if deaths or (rows and min(r['lives'] for r in rows) < rows[0]['lives']):
        reasons.append('death or life loss')
    if not rows or (rows[-1]['world'], rows[-1]['level'], rows[-1]['state']) != (3, 1, 'playing'):
        reasons.append('next-world normal control not reached')
    for stage in (2, 3, 4):
        if not any(r['world'] == 2 and r['level'] == stage and r['state'] == 'playing' for r in rows):
            reasons.append(f'no gameplay in 2-{stage}')
    return dict(passed=not reasons, reasons=reasons, frames=max(0, len(rows)-1),
                start=rows[0] if rows else None, end=rows[-1] if rows else None,
                stages=stages, death_frames=deaths,
                scope='continuous normal-entry host gameplay; not original-ROM strict acceptance')


if __name__ == '__main__':
    run_gameplay_route.validate_route = validate_campaign
    raise SystemExit(run_gameplay_route.main())
