/*
 * 8-Week Challenge - shared site settings loader
 *
 * Loads homepage / signup content from the public.competition_settings table.
 */

(function () {
  const client = window.sb;

  async function loadSettings() {
    try {
      const { data, error } = await client
        .from('competition_settings')
        .select('*')
        .single();
      if (error) throw error;
      return data || null;
    } catch (err) {
      console.error('loadSettings error:', err);
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
    formatCurrency: formatCurrency,
    formatPerWeek: formatPerWeek
  };
})();
