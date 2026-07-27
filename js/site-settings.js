/*
 * 8-Week Challenge - shared site settings loader
 *
 * Loads homepage / signup content from the public.competition_settings table,
 * merged with the active/next challenge's challenge_settings overrides.
 */

(function () {
  const client = window.sb;

  async function loadSettings(challengeId) {
    try {
      let targetId = challengeId;

      if (!targetId) {
        const { data: activeId, error: activeError } = await client.rpc(
          'active_or_next_challenge'
        );
        if (activeError) throw activeError;
        targetId = activeId || null;
      }

      if (!targetId) {
        const { data, error } = await client
          .from('competition_settings')
          .select('*')
          .single();
        if (error) throw error;
        return data || null;
      }

      const { data, error } = await client.rpc('get_effective_settings', {
        target_challenge_id: targetId
      });
      if (error) throw error;
      // Postgres functions returning TABLE(...) come back as an array of rows.
      const row = Array.isArray(data) ? data[0] : data;
      return row || null;
    } catch (err) {
      console.error('loadSettings error:', err);
      return null;
    }
  }

  async function loadChallengeSettings(challengeId) {
    try {
      const { data, error } = await client
        .from('challenge_settings')
        .select('*')
        .eq('challenge_id', challengeId)
        .single();
      if (error && error.code !== 'PGRST116') throw error;
      return data || null;
    } catch (err) {
      console.error('loadChallengeSettings error:', err);
      return null;
    }
  }

  function formatCurrency(amount) {
    if (amount === null || amount === undefined || isNaN(amount)) return '';
    return '$' + Number(amount).toLocaleString(undefined, { maximumFractionDigits: 0 });
  }

  function formatPerWeek(total) {
    if (!total && total !== 0) return '';
    return '$' + Math.round(total / 8);
  }

  window.siteSettings = {
    load: loadSettings,
    loadChallenge: loadChallengeSettings,
    formatCurrency: formatCurrency,
    formatPerWeek: formatPerWeek
  };

  // Expose formatCurrency globally too for pages that don't import it.
  window.formatCurrency = formatCurrency;
})();
