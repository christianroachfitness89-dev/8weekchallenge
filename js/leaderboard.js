/*
 * 8-Week Challenge — leaderboard data and rendering helpers
 *
 * Used by leaderboard.html and admin.html.
 */

(function () {
  const client = window.sb;

  async function fetchChallenges() {
    const { data, error } = await client
      .from('challenges')
      .select('*')
      .order('starts_at', { ascending: false });
    if (error) throw error;
    return data || [];
  }

  async function fetchLeaderboard(challengeId) {
    const { data, error } = await client.rpc('get_leaderboard', {
      target_challenge_id: challengeId
    });
    if (error) throw error;
    return data || [];
  }

  function formatPct(pct) {
    const sign = pct >= 0 ? '-' : '+';
    return sign + Math.abs(pct).toFixed(1) + '%';
  }

  function initials(name) {
    if (!name) return '?';
    const parts = name.trim().split(/\s+/);
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  function renderLeaderboard(rows, containerId, updatedId) {
    const container = document.getElementById(containerId);
    const updated = updatedId ? document.getElementById(updatedId) : null;

    if (!container) return;

    if (!rows || rows.length === 0) {
      container.innerHTML = '<div class="empty">No paid entries for this cohort yet. The leaderboard will populate once Week 0 weigh-ins are in.</div>';
      if (updated) updated.textContent = 'Updated ' + new Date().toLocaleTimeString();
      return;
    }

    rows.sort((a, b) => b.pct_lost - a.pct_lost);

    let html = '';
    rows.forEach(function (row, i) {
      const rankClass = i === 0 ? 'r1' : i === 1 ? 'r2' : i === 2 ? 'r3' : '';
      const pctText = formatPct(row.pct_lost);
      const displayName = escapeHtml(row.display_name || row.full_name);
      const subText = (row.weeks_logged || 0) + '/8 weeks logged' +
        (row.verified_weigh_ins ? ' · ' + row.verified_weigh_ins + '/3 verified' : '');

      html += '<div class="lb-row ' + rankClass + '">' +
        '<div class="lb-rank">' + (i + 1) + '</div>' +
        '<div><div class="lb-name">' + displayName + '</div>' +
        '<div class="lb-sub">' + subText + '</div></div>' +
        '<div class="lb-pct">' + pctText + '</div>' +
      '</div>';
    });

    container.innerHTML = html;
    if (updated) updated.textContent = 'Updated ' + new Date().toLocaleTimeString();
  }

  function escapeHtml(str) {
    const d = document.createElement('div');
    d.textContent = str;
    return d.innerHTML;
  }

  async function loadLeaderboard(containerId, updatedId, challengeId) {
    const container = document.getElementById(containerId);
    if (container) container.innerHTML = '<div class="loading">Loading leaderboard...</div>';
    try {
      const rows = await fetchLeaderboard(challengeId);
      renderLeaderboard(rows, containerId, updatedId);
    } catch (err) {
      console.error('Leaderboard load error:', err);
      if (container) container.innerHTML = '<div class="empty">Could not load the leaderboard. Try refreshing.</div>';
    }
  }

  window.leaderboard = {
    fetchChallenges: fetchChallenges,
    fetchLeaderboard: fetchLeaderboard,
    render: renderLeaderboard,
    load: loadLeaderboard,
    formatPct: formatPct,
    initials: initials
  };
})();
