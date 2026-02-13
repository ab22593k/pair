// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prepare_upload_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PrepareUploadResult {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PrepareUploadResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PrepareUploadResult()';
}


}

/// @nodoc
class $PrepareUploadResultCopyWith<$Res>  {
$PrepareUploadResultCopyWith(PrepareUploadResult _, $Res Function(PrepareUploadResult) __);
}


/// Adds pattern-matching-related methods to [PrepareUploadResult].
extension PrepareUploadResultPatterns on PrepareUploadResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Success value)?  success,TResult Function( _PinRequired value)?  pinRequired,TResult Function( _Declined value)?  declined,TResult Function( _RecipientBusy value)?  recipientBusy,TResult Function( _TooManyAttempts value)?  tooManyAttempts,TResult Function( _Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Success() when success != null:
return success(_that);case _PinRequired() when pinRequired != null:
return pinRequired(_that);case _Declined() when declined != null:
return declined(_that);case _RecipientBusy() when recipientBusy != null:
return recipientBusy(_that);case _TooManyAttempts() when tooManyAttempts != null:
return tooManyAttempts(_that);case _Error() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Success value)  success,required TResult Function( _PinRequired value)  pinRequired,required TResult Function( _Declined value)  declined,required TResult Function( _RecipientBusy value)  recipientBusy,required TResult Function( _TooManyAttempts value)  tooManyAttempts,required TResult Function( _Error value)  error,}){
final _that = this;
switch (_that) {
case _Success():
return success(_that);case _PinRequired():
return pinRequired(_that);case _Declined():
return declined(_that);case _RecipientBusy():
return recipientBusy(_that);case _TooManyAttempts():
return tooManyAttempts(_that);case _Error():
return error(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Success value)?  success,TResult? Function( _PinRequired value)?  pinRequired,TResult? Function( _Declined value)?  declined,TResult? Function( _RecipientBusy value)?  recipientBusy,TResult? Function( _TooManyAttempts value)?  tooManyAttempts,TResult? Function( _Error value)?  error,}){
final _that = this;
switch (_that) {
case _Success() when success != null:
return success(_that);case _PinRequired() when pinRequired != null:
return pinRequired(_that);case _Declined() when declined != null:
return declined(_that);case _RecipientBusy() when recipientBusy != null:
return recipientBusy(_that);case _TooManyAttempts() when tooManyAttempts != null:
return tooManyAttempts(_that);case _Error() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String sessionId,  Map<String, String> files)?  success,TResult Function()?  pinRequired,TResult Function()?  declined,TResult Function()?  recipientBusy,TResult Function()?  tooManyAttempts,TResult Function( String? error)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Success() when success != null:
return success(_that.sessionId,_that.files);case _PinRequired() when pinRequired != null:
return pinRequired();case _Declined() when declined != null:
return declined();case _RecipientBusy() when recipientBusy != null:
return recipientBusy();case _TooManyAttempts() when tooManyAttempts != null:
return tooManyAttempts();case _Error() when error != null:
return error(_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String sessionId,  Map<String, String> files)  success,required TResult Function()  pinRequired,required TResult Function()  declined,required TResult Function()  recipientBusy,required TResult Function()  tooManyAttempts,required TResult Function( String? error)  error,}) {final _that = this;
switch (_that) {
case _Success():
return success(_that.sessionId,_that.files);case _PinRequired():
return pinRequired();case _Declined():
return declined();case _RecipientBusy():
return recipientBusy();case _TooManyAttempts():
return tooManyAttempts();case _Error():
return error(_that.error);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String sessionId,  Map<String, String> files)?  success,TResult? Function()?  pinRequired,TResult? Function()?  declined,TResult? Function()?  recipientBusy,TResult? Function()?  tooManyAttempts,TResult? Function( String? error)?  error,}) {final _that = this;
switch (_that) {
case _Success() when success != null:
return success(_that.sessionId,_that.files);case _PinRequired() when pinRequired != null:
return pinRequired();case _Declined() when declined != null:
return declined();case _RecipientBusy() when recipientBusy != null:
return recipientBusy();case _TooManyAttempts() when tooManyAttempts != null:
return tooManyAttempts();case _Error() when error != null:
return error(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _Success implements PrepareUploadResult {
  const _Success({required this.sessionId, required final  Map<String, String> files}): _files = files;
  

 final  String sessionId;
 final  Map<String, String> _files;
 Map<String, String> get files {
  if (_files is EqualUnmodifiableMapView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_files);
}


/// Create a copy of PrepareUploadResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SuccessCopyWith<_Success> get copyWith => __$SuccessCopyWithImpl<_Success>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Success&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&const DeepCollectionEquality().equals(other._files, _files));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,const DeepCollectionEquality().hash(_files));

@override
String toString() {
  return 'PrepareUploadResult.success(sessionId: $sessionId, files: $files)';
}


}

/// @nodoc
abstract mixin class _$SuccessCopyWith<$Res> implements $PrepareUploadResultCopyWith<$Res> {
  factory _$SuccessCopyWith(_Success value, $Res Function(_Success) _then) = __$SuccessCopyWithImpl;
@useResult
$Res call({
 String sessionId, Map<String, String> files
});




}
/// @nodoc
class __$SuccessCopyWithImpl<$Res>
    implements _$SuccessCopyWith<$Res> {
  __$SuccessCopyWithImpl(this._self, this._then);

  final _Success _self;
  final $Res Function(_Success) _then;

/// Create a copy of PrepareUploadResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? files = null,}) {
  return _then(_Success(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

/// @nodoc


class _PinRequired implements PrepareUploadResult {
  const _PinRequired();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PinRequired);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PrepareUploadResult.pinRequired()';
}


}




/// @nodoc


class _Declined implements PrepareUploadResult {
  const _Declined();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Declined);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PrepareUploadResult.declined()';
}


}




/// @nodoc


class _RecipientBusy implements PrepareUploadResult {
  const _RecipientBusy();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecipientBusy);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PrepareUploadResult.recipientBusy()';
}


}




/// @nodoc


class _TooManyAttempts implements PrepareUploadResult {
  const _TooManyAttempts();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TooManyAttempts);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PrepareUploadResult.tooManyAttempts()';
}


}




/// @nodoc


class _Error implements PrepareUploadResult {
  const _Error({required this.error});
  

 final  String? error;

/// Create a copy of PrepareUploadResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ErrorCopyWith<_Error> get copyWith => __$ErrorCopyWithImpl<_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Error&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'PrepareUploadResult.error(error: $error)';
}


}

/// @nodoc
abstract mixin class _$ErrorCopyWith<$Res> implements $PrepareUploadResultCopyWith<$Res> {
  factory _$ErrorCopyWith(_Error value, $Res Function(_Error) _then) = __$ErrorCopyWithImpl;
@useResult
$Res call({
 String? error
});




}
/// @nodoc
class __$ErrorCopyWithImpl<$Res>
    implements _$ErrorCopyWith<$Res> {
  __$ErrorCopyWithImpl(this._self, this._then);

  final _Error _self;
  final $Res Function(_Error) _then;

/// Create a copy of PrepareUploadResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = freezed,}) {
  return _then(_Error(
error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
