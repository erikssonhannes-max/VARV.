// Inställningarna för VARV. i appen Zepp: här skrivs koden från VARV. in.
// Sidotjänsten (app-side/index.js) byter koden mot klockans egen nyckel och skriver svaret i status.
AppSettingsPage({
  build(props) {
    const s = props.settingsStorage
    const linked = !!s.getItem('token')
    const status = s.getItem('status') || ''
    return View({ style: { padding: '16px 20px' } }, [
      Text(
        { paragraph: true, style: { fontSize: '16px', fontWeight: '600', marginBottom: '8px' } },
        linked ? 'Klockan är kopplad till VARV.' : 'Koppla klockan till VARV.'
      ),
      Text(
        { paragraph: true, style: { fontSize: '14px', color: '#6e6e76', marginBottom: '16px', lineHeight: '20px' } },
        'Öppna VARV. på telefonen och gå till Profil, Inställningar, Klockor. Tryck Koppla en klocka och skriv in koden här. Koden gäller i 15 minuter.'
      ),
      TextInput({
        label: 'Kod från VARV.',
        placeholder: 'ABCD 2345',
        value: '',
        onChange: (v) => s.setItem('code', String(v || '').replace(/\s/g, '').toUpperCase())
      }),
      status
        ? Text({ paragraph: true, style: { fontSize: '14px', marginTop: '16px', lineHeight: '20px' } }, status)
        : null
    ].filter(Boolean))
  }
})
