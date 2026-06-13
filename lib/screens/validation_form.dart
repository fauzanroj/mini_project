enum VehicleExteriorCondition { baik, lecetRingan, rusak, sangatRusak }

enum VehicleEngineCondition { hidupNormal, hidupTidakNormal, mati }

class VehicleInspectionDraft {
  const VehicleInspectionDraft({
    required this.nomorPolisi,
    required this.kilometer,
    required this.kondisiMesin,
    required this.kondisiEksterior,
    required this.bisaDipindahkan,
    this.alasanTidakBisaDipindahkan,
    this.catatanTambahan,
  });

  final String nomorPolisi;
  final int kilometer;
  final VehicleEngineCondition kondisiMesin;
  final VehicleExteriorCondition kondisiEksterior;
  final bool bisaDipindahkan;
  final String? alasanTidakBisaDipindahkan;
  final String? catatanTambahan;
}
