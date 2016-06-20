with
lfs as
(
  select e.snap_id,
         e.total_waits - lag(e.total_waits) over (partition by e.event_name order by e.snap_id) waits_delta,
         e.time_waited_micro - lag(e.time_waited_micro) OVER (PARTITION BY e.event_name ORDER BY e.snap_id) time_delta
  from dba_hist_system_event e
  where e.event_name = 'log file sync'
),
lfpw as
(
  select e.snap_id,
         e.total_waits - lag(e.total_waits) over (partition by e.event_name order by e.snap_id) waits_delta,
         e.time_waited_micro - lag(e.time_waited_micro) OVER (PARTITION BY e.event_name ORDER BY e.snap_id) time_delta
  from dba_hist_system_event e
  where e.event_name = 'log file parallel write'
),
redo as
(
  SELECT  snap_id,
          (VALUE - lag(VALUE) OVER (PARTITION BY stat_name ORDER BY snap_id))/1024/1024 redo_size
  FROM dba_hist_sysstat
  WHERE stat_name = 'redo size'
  ORDER BY snap_id DESC
),
snap as
(
  select snap_id,
         trunc(begin_interval_time, 'mi') begin_interval_time,
         end_interval_time - begin_interval_time interval_duration
  from dba_hist_snapshot
),
sn as
(
  select snap_id,
         begin_interval_time,
         extract(hour from interval_duration)*3600+
         extract(minute from interval_duration)*60+
         extract(second from interval_duration) seconds_in_snap
  from snap
),
ash as
(
  select snap_id, max(active_sess) max_concurrency
  from
  (
    select snap_id, sample_time, count(*) active_sess
    from dba_hist_active_sess_history ash
    where event = 'log file sync'
    group by snap_id, sample_time
  )
  group by snap_id
),
requests as
(
  select snap_id, avg(p3) avg_lfpw_requests
  from dba_hist_active_sess_history ash
  where event = 'log file parallel write'
  group by snap_id
)
select begin_interval_time,
       round(redo.redo_size/seconds_in_snap,2) redo_gen_MB_per_sec,
       round(100*lfpw.time_delta/1e6/seconds_in_snap) lgwr_pct_busy,
       round(avg_lfpw_requests, 2) avg_requests_per_log_write,
       round(1e6*redo.redo_size/lfpw.time_delta, 2) redo_write_speed,
       round(redo.redo_size/lfpw.waits_delta, 2) avg_redo_write_size,
       round(lfs.time_delta/lfs.waits_delta/1000,2) avg_lfs,
       round(lfpw.time_delta/lfpw.waits_delta/1000,2) avg_lfpw,
       lfs.waits_delta lfs_num_waits,
       lfpw.waits_delta lfpw_num_waits,
       max_concurrency
from lfs,
     lfpw,
     sn,
     redo,
     ash,
     requests
where lfs.snap_id (+) = sn.snap_id
and lfpw.snap_id (+) = sn.snap_id
and redo.snap_id (+) = sn.snap_id
and ash.snap_id = sn.snap_id
and requests.snap_id = sn.snap_id
order by begin_interval_time desc
