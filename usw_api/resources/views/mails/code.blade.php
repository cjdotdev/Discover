<!doctype html>
<html lang="{{ app()->getLocale() }}">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;padding:32px 16px;background:#f3f1fb;font-family:system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;color:#121212">
  <div style="max-width:420px;margin:0 auto;background:#ffffff;border-radius:22px;padding:28px 24px">
    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 16px"><tr>
      @if ($logo)
      <td style="padding:0 10px 0 0"><img src="{{ $logo }}" width="40" height="40" alt="" style="display:block;border-radius:10px"></td>
      @endif
      <td style="font-size:16px;font-weight:700">Discover</td>
    </tr></table>
    <p style="margin:0 0 20px;font-size:15px;line-height:1.5">{{ $intro }}</p>
    <p style="margin:0 0 20px;font-size:34px;font-weight:700;letter-spacing:8px">{{ $code }}</p>
    <p style="margin:0;font-size:13px;line-height:1.5;color:#6b6f80">
      {{ __('Ce code est valable 10 minutes. Si vous n’avez rien demandé, ignorez ce message : personne ne peut se connecter sans ce code.') }}
    </p>
  </div>
</body>
</html>
