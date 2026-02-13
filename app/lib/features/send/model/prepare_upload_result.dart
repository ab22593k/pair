import 'package:freezed_annotation/freezed_annotation.dart';

part 'prepare_upload_result.freezed.dart';

@freezed
sealed class PrepareUploadResult with _$PrepareUploadResult {
  const factory PrepareUploadResult.success({
    required String sessionId,
    required Map<String, String> files,
  }) = _Success;

  const factory PrepareUploadResult.pinRequired() = _PinRequired;

  const factory PrepareUploadResult.declined() = _Declined;

  const factory PrepareUploadResult.recipientBusy() = _RecipientBusy;

  const factory PrepareUploadResult.tooManyAttempts() = _TooManyAttempts;

  const factory PrepareUploadResult.error({
    required String? error,
  }) = _Error;
}
