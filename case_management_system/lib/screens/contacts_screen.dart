import 'package:flutter_contacts/flutter_contacts.dart';
import 'dart:convert';

class ContactJSONSafe {
  String? id;
  String? displayName;
  Name? name;
  List<Phone> phones;
  List<Email> emails;
  List<Address> addresses;
  List<Organization> organizations;
  List<Website> websites;
  List<SocialMedia> socialMedias;
  List<Event> events;
  List<Note> notes;
  List<Group> groups;
  String? photoBase64; // Base64 encoded photo
  String? thumbnailBase64; // Base64 encoded thumbnail

  // Constructor to create JSON-safe ContactJSONSafe from an existing Contact
  ContactJSONSafe.fromContact(Contact contact)
      : id = contact.id,
        displayName = contact.displayName,
        name = contact.name,
        phones = contact.phones,
        emails = contact.emails,
        addresses = contact.addresses,
        organizations = contact.organizations,
        websites = contact.websites,
        socialMedias = contact.socialMedias,
        events = contact.events,
        notes = contact.notes,
        groups = contact.groups,
        photoBase64 =
            contact.photo != null ? base64Encode(contact.photo!) : null,
        thumbnailBase64 =
            contact.thumbnail != null ? base64Encode(contact.thumbnail!) : null;

  // Convert ContactJSONSafe back to a regular Contact
  Contact toContact() {
    return Contact(
      id: id ?? '',
      displayName: displayName ?? '',
      name: name!,
      phones: phones,
      emails: emails,
      addresses: addresses,
      organizations: organizations,
      websites: websites,
      socialMedias: socialMedias,
      events: events,
      notes: notes,
      groups: groups,
      photo: photoBase64 != null ? base64Decode(photoBase64!) : null,
      thumbnail:
          thumbnailBase64 != null ? base64Decode(thumbnailBase64!) : null,
    );
  }

  // Convert to JSON-safe map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'name': name?.toJson(),
      'phones': phones.map((e) => e.toJson()).toList(),
      'emails': emails.map((e) => e.toJson()).toList(),
      'addresses': addresses.map((e) => e.toJson()).toList(),
      'organizations': organizations.map((e) => e.toJson()).toList(),
      'websites': websites.map((e) => e.toJson()).toList(),
      'socialMedias': socialMedias.map((e) => e.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'notes': notes.map((e) => e.toJson()).toList(),
      'groups': groups.map((e) => e.toJson()).toList(),
      'photo': photoBase64,
      'thumbnail': thumbnailBase64,
    };
  }

  // Factory method to construct ContactJSONSafe from JSON
  factory ContactJSONSafe.fromJson(Map<String, dynamic> json) {
    return ContactJSONSafe.fromContact(Contact(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      name: Name.fromJson(json['name']),
      phones: (json['phones'] as List<dynamic>)
          .map((e) => Phone.fromJson(e))
          .toList(),
      emails: (json['emails'] as List<dynamic>)
          .map((e) => Email.fromJson(e))
          .toList(),
      addresses: (json['addresses'] as List<dynamic>)
          .map((e) => Address.fromJson(e))
          .toList(),
      organizations: (json['organizations'] as List<dynamic>)
          .map((e) => Organization.fromJson(e))
          .toList(),
      websites: (json['websites'] as List<dynamic>)
          .map((e) => Website.fromJson(e))
          .toList(),
      socialMedias: (json['socialMedias'] as List<dynamic>)
          .map((e) => SocialMedia.fromJson(e))
          .toList(),
      events: (json['events'] as List<dynamic>)
          .map((e) => Event.fromJson(e))
          .toList(),
      notes: (json['notes'] as List<dynamic>)
          .map((e) => Note.fromJson(e))
          .toList(),
      groups: (json['groups'] as List<dynamic>)
          .map((e) => Group.fromJson(e))
          .toList(),
      photo: json['photo'] != null ? base64Decode(json['photo']) : null,
      thumbnail:
          json['thumbnail'] != null ? base64Decode(json['thumbnail']) : null,
    ));
  }
}
