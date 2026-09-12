// Published runs retain their exact release; boards span one major/minor pair.
export function minorVersion(version: string) {
  return version === 'dev' ? version : version.split('.').slice(0, 2).join('.')
}

export function validBoardVersion(version: string) {
  return version === 'dev' || /^(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})(\.(0|[1-9]\d{0,5}))?$/.test(version)
}

export function versionLabel(version: string) {
  return version === 'dev' ? 'dev' : `v${minorVersion(version)}.x`
}
